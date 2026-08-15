//
//  FirebaseService.swift
//  Tweli
//
//  Real Firebase sync for the couple space (free — Spark plan, no server).
//
//  Design: one Firestore document per couple (`spaces/{spaceId}`) holds the
//  membership (max two Firebase UIDs) plus six item subcollections. Each item is
//  stored as a "thin payload" document — the Codable model JSON-encoded into a
//  single `payload` string field — which keeps the mapping to our models tiny and
//  identical to the CloudKit port it replaces. A 6-char pair code
//  (`pairCodes/{code}`, code == doc id) is the whole invite: it carries the
//  spaceId, so redeeming is a direct getDocument with no queryable index.
//
//  This is a drop-in replacement for `CloudKitService`: the same method names,
//  static helpers (`normalizePairCode`, `codeAlphabet`), and nested types
//  (`Role`, `RType`, `PairCodeError`, `RemoteChanges`) so almost every caller is
//  untouched. The deliberate exceptions (`PairInvite` replacing CKShare.Metadata,
//  the new `spaceFull` join outcome) are documented in the migration specs.
//
//  Why Firebase over CloudKit: CloudKit writes land in the *user's* iCloud, so a
//  user at their 5 GB limit got quotaExceeded on the very first write. Firestore
//  storage counts against the project — a user can never be blocked by their own
//  storage again.
//
//  Two identities coexist and must never be conflated: the Firebase UID (String,
//  membership + security rules) and the app profile UUID (UserProfile.id, which
//  stays inside the item payloads). The Firebase UID never enters a payload.
//
//  DEBUG bypass: `devSignIn()` sets a synthetic `dev-` uid and makes NO network
//  call; every Firestore read/write/listener short-circuits on a `dev-` (or nil)
//  uid, so debug builds run entirely on the local stores (which start empty).
//  Compile-time
//  Excluded from release builds.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

@MainActor
final class FirebaseService: ObservableObject {

    // MARK: - Config

    enum Role: String { case none, owner, participant }
    @Published private(set) var role: Role
    /// "A Firebase user is signed in" — NOT iCloud status (the CloudKit meaning).
    @Published private(set) var accountAvailable = false

    /// The signed-in Firebase Auth UID (membership + security-rule identity). In a
    /// DEBUG bypass session this is a synthetic `dev-` value; otherwise it mirrors
    /// `Auth.auth().currentUser?.uid`.
    private(set) var currentUid: String?

    /// The couple's space document id, cached in UserDefaults across launches.
    private(set) var spaceId: String?

    private let defaults = UserDefaults.standard
    private let roleKey = "tweli.fb.role"
    private let spaceIdKey = "tweli.fb.spaceId"
    private let pairCodeKey = "tweli.fb.pairCode"
    private let pairCodeExpiryKey = "tweli.fb.pairCodeExpiry"

    /// When the current pair code stops working. Drives the invite screen's
    /// "Expires in N hours" line and its expired state (comp A5 / E3).
    @Published private(set) var pairCodeExpiresAt: Date?

    /// The pair code currently published for this space — the one that actually
    /// redeems. NOT `CoupleSpace.inviteCode`, which is a local UUID slice that
    /// was never written to Firestore and would never let anyone in.
    var activePairCode: String? {
        let code = defaults.string(forKey: pairCodeKey) ?? ""
        return code.isEmpty ? nil : code
    }
    /// Same key AuthService persists the display name under — the owner/participant
    /// name written into `memberNames` and pair codes is read from here so
    /// `createSpace(title:)` / `publishPairCode` need no extra name argument.
    private let authNameKey = "tweli.auth.displayName"

    /// Firestore subcollection names — plural lowercase, matching database.md
    /// paths. Callers reference these symbolically (never string literals), so the
    /// values could change safely; these are the coordinated collection names.
    enum RType {
        static let reminder = "reminders", countdown = "countdowns", letter = "letters"
        static let virtualDate = "virtualDates", mood = "moods", ping = "pings"
        static let location = "locations"
        static let all = [reminder, countdown, letter, virtualDate, mood, ping, location]
    }

    private var listeners: [ListenerRegistration] = []

    /// Set when a live listener fails in a way retrying won't fix — the space is
    /// gone, or this user is no longer allowed to read it. Drives comp E8.
    /// Transient errors (offline, timeouts) are NOT reported here: Firestore's
    /// cache keeps serving, and a network blip must never take over the screen.
    @Published private(set) var fatalSyncError: String?

    init() {
        role = Role(rawValue: defaults.string(forKey: roleKey) ?? "none") ?? .none
        spaceId = defaults.string(forKey: spaceIdKey)
        // Firebase persists the session in the Keychain automatically. Only read it
        // if the app is already configured (FirebaseApp.configure() runs in the app
        // delegate, which may or may not have fired before this composition-root
        // init) — otherwise leave it for refreshAccountStatus() to pick up.
        if FirebaseApp.app() != nil {
            currentUid = Auth.auth().currentUser?.uid
            accountAvailable = currentUid != nil
        }
    }

    /// Lazily resolved Firestore handle with the persistent offline cache enabled.
    /// Lazy so `init()` never touches Firestore before `FirebaseApp.configure()`;
    /// the first access happens on a real user action, well after launch. Settings
    /// can only be applied before the first use, which this guarantees.
    private lazy var db: Firestore = {
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        return firestore
    }()

    private func setRole(_ r: Role) { role = r; defaults.set(r.rawValue, forKey: roleKey) }

    private func setSpaceId(_ id: String?) {
        spaceId = id
        if let id { defaults.set(id, forKey: spaceIdKey) } else { defaults.removeObject(forKey: spaceIdKey) }
    }

    /// The signed-in display name, read from the same UserDefaults key AuthService
    /// writes. Used for `memberNames` and the pair code's `createdByName`.
    private var displayName: String {
        let name = defaults.string(forKey: authNameKey) ?? ""
        return name.isEmpty ? "You" : name
    }

    /// True when there is no real signed-in Firebase user — either nobody is signed
    /// in, or this is a DEBUG bypass (`dev-` uid). Every network operation early
    /// returns on this so debug builds stay fully offline on the local stores.
    private var isDevOrOffline: Bool {
        guard let uid = currentUid else { return true }
        return uid.hasPrefix("dev-")
    }

    // MARK: - Account

    func refreshAccountStatus() async {
        guard FirebaseApp.app() != nil else { accountAvailable = false; return }
        // Keep a DEBUG bypass session available without any network probe.
        if currentUid?.hasPrefix("dev-") == true { accountAvailable = true; return }
        currentUid = Auth.auth().currentUser?.uid
        accountAvailable = currentUid != nil
    }

    // MARK: - Auth (Sign in with Apple → Firebase Auth)

    struct FirebaseUser { let uid: String; let displayName: String }

    /// Exchange a verified Apple credential for a Firebase session (nonce flow).
    /// Called by AuthService from the SignInWithAppleButton completion. Returns the
    /// Firebase UID + best-known display name so AuthService persists them as today.
    func signInWithApple(idToken: String, rawNonce: String,
                         fullName: PersonNameComponents?) async throws -> FirebaseUser {
        let credential = OAuthProvider.appleCredential(withIDToken: idToken,
                                                       rawNonce: rawNonce,
                                                       fullName: fullName)
        let result = try await Auth.auth().signIn(with: credential)
        let uid = result.user.uid
        currentUid = uid
        accountAvailable = true

        // Display name: Apple's fullName (first auth only), else the persisted name,
        // else the "You" fallback — mirrors AuthService.store()'s resolution.
        var name = ""
        if let fullName {
            name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
        }
        if name.isEmpty { name = defaults.string(forKey: authNameKey) ?? "" }
        if name.isEmpty { name = "You" }
        log("signed in uid=\(uid)")
        return FirebaseUser(uid: uid, displayName: name)
    }

    /// Firebase Auth sign-out; clears role + spaceId. No-op (beyond local clear) in
    /// a DEBUG bypass session, where there is no Firebase user.
    func signOut() throws {
        if FirebaseApp.app() != nil, currentUid?.hasPrefix("dev-") != true {
            try Auth.auth().signOut()
        }
        currentUid = nil
        accountAvailable = false
        reset()
    }

#if DEBUG
    /// Dev bypass — synthetic uid, no network. FirebaseService treats a `dev-` uid
    /// as offline, so all Firestore reads/writes/listeners short-circuit. It seeds
    /// no content — the app still opens on genuinely empty state.
    func devSignIn() {
        currentUid = "dev-\(UUID().uuidString)"
        accountAvailable = true
    }
#endif

    // MARK: - Pairing codes

    enum PairCodeError: LocalizedError {
        case notFound, expired, badShareURL, spaceFull, network

        var errorDescription: String? {
            switch self {
            case .notFound: return "That code wasn't found. Double-check it, or ask your partner for a fresh one."
            case .expired: return "That code has expired. Ask your partner to create a new invite."
            case .badShareURL: return "This invite looks broken. Ask your partner to create a new one."
            case .spaceFull: return "This space already has two people. Ask your partner to send you a fresh invite."
            case .network: return "Couldn't check the code right now. Check your connection and try again."
            }
        }
    }

    /// Invite metadata for the confirm-join sheet — the plain-struct replacement for
    /// CKShare.Metadata.
    struct PairInvite: Identifiable {
        let spaceId: String
        let spaceTitle: String
        let inviterName: String
        var id: String { spaceId }
    }

    // MARK: - Pair codes (comp A5/A6 — "TWLI-4821")

    /// Letters, minus the ones that read as digits (I, L, O).
    static let codeLetters = Array("ABCDEFGHJKMNPQRSTUVWXYZ")
    /// Digits. O is absent from the letters above, so 0 is unambiguous here.
    static let codeDigits = Array("0123456789")
    /// Everything a code can contain — used to strip separators on input.
    static let codeAlphabet = codeLetters + codeDigits

    /// The comp writes codes as `TWLI-4821`: four letters, a hyphen, four
    /// digits. We keep that exact shape but make BOTH halves random — a fixed
    /// "TWLI" prefix would leave only 10,000 possible codes. Four letters plus
    /// four digits is 23⁴ × 10⁴ ≈ 2.8 billion, which is a real invite code that
    /// still reads like the one in the design.
    ///
    /// One deviation: the comp's literal example "TWLI" contains I and L, which
    /// are excluded above because they are unreadable next to 1. So that exact
    /// string can never be minted, and the UI hint shows the shape
    /// ("ABC-123") rather than an example the app could never issue.
    /// SIX. Every pair code that has ever existed in this project is six
    /// characters (FECY63, HW5YEC, K8779U…), and the comps draw six boxes. An
    /// eight-character format was introduced by a design rewrite and never
    /// minted a single real code — while an eight-cell entry screen silently
    /// rejects every invite anyone actually holds.
    static let codeLength = 6

    /// Internal (not private) so the test suite can assert that every minted
    /// code round-trips through normalize/format.
    ///
    /// Three letters then three digits keeps the halves readable while staying
    /// six long: 23³ × 10³ ≈ 12 million, which is ample for invites that expire
    /// in 48 hours and are single-use.
    static func makeCode() -> String {
        let letters = (0..<3).map { _ in codeLetters.randomElement()! }
        let digits = (0..<3).map { _ in codeDigits.randomElement()! }
        return String(letters + digits)
    }

    /// Uppercases and strips separators so "twli 4821" and "TWLI-4821" both
    /// resolve to the stored document id "TWLI4821".
    static func normalizePairCode(_ raw: String) -> String {
        raw.uppercased().filter { codeAlphabet.contains($0) }
    }

    /// Display form — "HW5YEC" → "HW5-YEC". Split down the middle so the two
    /// halves are easy to read aloud, which is how most invites travel.
    static func formatPairCode(_ raw: String) -> String {
        let code = normalizePairCode(raw)
        guard code.count == codeLength else { return code }
        let i = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<i])-\(code[i...])"
    }

    /// A code is enterable once it is exactly six characters. There is no
    /// second accepted length any more: the eight-character format never
    /// reached a user, so accepting it would only let someone submit a code
    /// that cannot exist.
    static func isPlausiblePairCode(_ raw: String) -> Bool {
        normalizePairCode(raw).count == codeLength
    }

    // MARK: - Notification preferences (comp V3)

    /// Load my own preferences from the space doc. Falls back to the defaults,
    /// which match the behaviour that was previously hard-coded server-side.
    func loadNotificationPreferences() async -> NotificationPreferences {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { return .default }
        do {
            let snap = try await db.collection("spaces").document(spaceId).getDocument()
            guard let all = snap.data()?["notificationPrefs"] as? [String: Any],
                  let mine = all[uid] as? [String: Any] else { return .default }
            return NotificationPreferences(firestore: mine)
        } catch {
            log("loadNotificationPreferences failed: \(error.localizedDescription)")
            return .default
        }
    }

    /// Persist my preferences where the push function can read them. Writing to
    /// `notificationPrefs.<uid>` keeps it a member edit, so the existing rule
    /// covers it without a rules change.
    func saveNotificationPreferences(_ prefs: NotificationPreferences) async {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { return }
        do {
            try await db.collection("spaces").document(spaceId).updateData([
                FieldPath(["notificationPrefs", uid]): prefs.firestoreValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            log("saved notification preferences")
        } catch {
            log("saveNotificationPreferences failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Space recovery

    /// What a recovered space carries back to the client.
    struct RecoveredSpace {
        let spaceId: String
        let title: String
        let isOwner: Bool
        /// The other member's name, if the space already has two people.
        let partnerName: String?

        /// MY OWN profile, read back off the same space document.
        ///
        /// Recovery used to restore membership but not identity, which was fine
        /// until the profile grew fields worth keeping. After a reinstall the
        /// device has an empty `currentUser` while Firestore still holds the
        /// real one — so the app walked the user back through X1–X6 with blank
        /// fields, and finishing that pushed the blanks back up, deleting their
        /// bio and birthday from the partner's copy too.
        let myName: String?
        let myBio: String?
        let myCity: String?
        let myBirthday: Date?

        /// Enough of a profile came back that re-asking would be rude.
        var hasProfile: Bool {
            !(myName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        }
    }

    /// Finds the caller's space by MEMBERSHIP rather than by cached id.
    ///
    /// `signOut()` clears role + spaceId, and spaceId was only ever restored
    /// from UserDefaults — so a fresh install, a new phone, or a sign-out and
    /// back in landed on Start-or-join even though the user is still in
    /// `memberUids` and all their data is intact. It reads as "the app lost my
    /// partner". This is the missing lookup.
    ///
    /// Rules-safe without any change to firestore.rules: the space `list` rule
    /// already allows `request.auth.uid in resource.data.memberUids`, which is
    /// exactly what this query filters on.
    ///
    /// Returns nil when there is nothing to recover — including when a spaceId
    /// is already cached, since then there is nothing lost to find.
    /// Choose which space to recover into when the user belongs to several.
    ///
    /// The order is deliberate, and it is about which space a person would
    /// actually name if you asked them:
    ///
    ///   1. Skip anything they have left — `leftBy` is theirs and they are no
    ///      longer a member. Being recovered into a space you walked out of is
    ///      worse than not being recovered at all.
    ///   2. Prefer a space that has TWO people. A one-person space is either
    ///      abandoned or not yet joined; the paired one is the relationship.
    ///   3. Then most recently active, by `updatedAt`. Among equals, the one
    ///      they last used.
    ///
    /// Static and pure so it can be tested without Firestore — the selection is
    /// the part that was wrong, and it deserves to be checkable.
    nonisolated static func bestSpace(from documents: [QueryDocumentSnapshot],
                                      uid: String) -> QueryDocumentSnapshot? {
        func members(_ d: QueryDocumentSnapshot) -> [String] {
            d.data()["memberUids"] as? [String] ?? []
        }
        func updatedAt(_ d: QueryDocumentSnapshot) -> Date {
            (d.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        }

        let live = documents.filter { d in
            let m = members(d)
            guard m.contains(uid) else { return false }        // stale index entry
            if (d.data()["leftBy"] as? String) == uid, !m.contains(uid) { return false }
            return true
        }

        return live.max { a, b in
            let pairedA = members(a).count >= 2, pairedB = members(b).count >= 2
            if pairedA != pairedB { return !pairedA }          // paired wins
            return updatedAt(a) < updatedAt(b)                 // then most recent
        }
    }

    func restoreSpaceMembership() async -> RecoveredSpace? {
        guard !isDevOrOffline, let uid = currentUid, spaceId == nil else { return nil }
        do {
            // NO `.limit(to: 1)`. That assumed one membership per person, which
            // the two-person cap makes *feel* true — but the cap is per space,
            // not per user. Anyone who has created a space, left it, and joined
            // another is in several, and an unordered single-document query
            // returns an arbitrary one. Observed live: a user with a real
            // two-person space plus an empty leftover was recovered into the
            // leftover, which reads as "the app put me in a group I never made".
            let snap = try await db.collection("spaces")
                .whereField("memberUids", arrayContains: uid)
                .getDocuments()

            guard let doc = Self.bestSpace(from: snap.documents, uid: uid) else {
                log("no existing space to recover for uid=\(uid)")
                return nil
            }
            if snap.documents.count > 1 {
                log("recovery: \(snap.documents.count) memberships, chose \(doc.documentID)")
            }
            let data = doc.data()
            let members = data["memberUids"] as? [String] ?? []
            let names = data["memberNames"] as? [String: String] ?? [:]
            let isOwner = (data["ownerUid"] as? String) == uid
            let partnerUid = members.first { $0 != uid }

            setSpaceId(doc.documentID)
            setRole(isOwner ? .owner : .participant)
            log("recovered space \(doc.documentID) by membership (owner: \(isOwner))")

            // My own half of the same document. The values are already in this
            // snapshot, so recovering identity alongside membership costs no
            // extra read.
            func mine(_ key: String) -> String? {
                let map = data[key] as? [String: String] ?? [:]
                guard let raw = map[uid] else { return nil }
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }

            return RecoveredSpace(
                spaceId: doc.documentID,
                title: (data["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Our space",
                isOwner: isOwner,
                partnerName: partnerUid.flatMap { names[$0] },
                myName: names[uid].flatMap { $0.isEmpty ? nil : $0 },
                myBio: mine("memberBios"),
                myCity: mine("memberCities"),
                myBirthday: mine("memberBirthdays").flatMap { Self.birthdayFormatter.date(from: $0) }
            )
        } catch {
            // A failure here must not block sign-in; the user simply lands on
            // Start-or-join as they did before, and the next launch retries.
            log("restoreSpaceMembership failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Space + pairing (invite flow)

    /// Owner: create the couple space document and become owner. Replaces
    /// createShare() — one Firestore write, no server-minted URL to wait for.
    func createSpace(title: String) async throws -> String {
        guard !isDevOrOffline, let uid = currentUid else { throw PairCodeError.network }
        let ref = db.collection("spaces").document()   // auto-id
        do {
            try await ref.setData([
                "title": title,
                "ownerUid": uid,
                "memberUids": [uid],
                "memberNames": [uid: displayName],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            log("createSpace failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        setRole(.owner)
        setSpaceId(ref.documentID)
        log("created space \(ref.documentID) “\(title)”")
        return ref.documentID
    }

    /// Owner: publish (or reuse an unexpired) pair code pointing at this
    /// space. The code IS the document id, so redemption is a direct getDocument —
    /// no query index, no dashboard setup.
    func publishPairCode(spaceTitle: String) async throws -> String {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { throw PairCodeError.network }

        // Reuse a previously published, unexpired code so re-visits show the same
        // one — but ONLY if it still points at the CURRENT space. A cached code
        // from a previous space (re-created after sign-out/reinstall) would send
        // the partner into an orphaned space the owner no longer listens to.
        if let cached = defaults.string(forKey: pairCodeKey),
           let doc = try? await db.collection("pairCodes").document(cached).getDocument(),
           doc.exists,
           doc["spaceId"] as? String == spaceId,
           let expires = (doc["expiresAt"] as? Timestamp)?.dateValue(), expires > Date() {
            log("reusing pair code \(cached)")
            await MainActor.run { self.pairCodeExpiresAt = expires }
            defaults.set(expires, forKey: pairCodeExpiryKey)
            return cached
        }

        let code = Self.makeCode()
        let expires = Date().addingTimeInterval(48 * 3600)   // 48h, per comp A5
        do {
            try await db.collection("pairCodes").document(code).setData([
                "spaceId": spaceId,
                "spaceTitle": spaceTitle,
                "createdBy": uid,
                "createdByName": displayName,
                "expiresAt": Timestamp(date: expires),
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            log("publishPairCode failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        defaults.set(code, forKey: pairCodeKey)
        defaults.set(expires, forKey: pairCodeExpiryKey)
        await MainActor.run { self.pairCodeExpiresAt = expires }
        log("published pair code \(code) → space \(spaceId)")
        return code
    }

    /// Owner: discard the cached code and mint a brand-new one (comp E3
    /// "Generate a fresh code"). The old code simply expires on its own.
    func regeneratePairCode(spaceTitle: String) async throws -> String {
        defaults.removeObject(forKey: pairCodeKey)
        defaults.removeObject(forKey: pairCodeExpiryKey)
        await MainActor.run { self.pairCodeExpiresAt = nil }
        return try await publishPairCode(spaceTitle: spaceTitle)
    }

    /// Partner: turn a typed/deep-linked code into invite metadata for the confirm
    /// sheet. A missing doc is `.notFound`; any OTHER read failure is `.network`,
    /// never `.notFound` — telling a user a valid code is wrong makes them give up.
    func redeemPairCode(_ raw: String) async throws -> PairInvite {
        let code = Self.normalizePairCode(raw)
        let snap: DocumentSnapshot
        do {
            snap = try await db.collection("pairCodes").document(code).getDocument()
        } catch {
            log("redeem \(code) failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        guard snap.exists, let data = snap.data() else {
            log("redeem \(code): no such code")
            throw PairCodeError.notFound
        }
        if let expires = (data["expiresAt"] as? Timestamp)?.dateValue(), expires < Date() {
            throw PairCodeError.expired
        }
        guard let spaceId = data["spaceId"] as? String, !spaceId.isEmpty else {
            throw PairCodeError.badShareURL
        }
        let title = (data["spaceTitle"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "your shared space"
        let inviter = (data["createdByName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Your partner"
        log("redeemed pair code \(code) → space \(spaceId)")
        return PairInvite(spaceId: spaceId, spaceTitle: title, inviterName: inviter)
    }

    /// Partner: atomically join the space named by a redeemed PairInvite. A Firestore
    /// transaction enforces the friendly path (max 2, no takeover, "space is full");
    /// the security rules independently enforce the same guarantees.
    func joinSpace(_ invite: PairInvite, participantName: String) async throws {
        guard !isDevOrOffline, let uid = currentUid else { throw PairCodeError.network }
        let ref = db.collection("spaces").document(invite.spaceId)
        do {
            _ = try await db.runTransaction { txn, errorPointer in
                let snap: DocumentSnapshot
                do {
                    snap = try txn.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                let members = snap.data()?["memberUids"] as? [String] ?? []
                // Already a member → nothing to do (idempotent re-join).
                if members.contains(uid) { return nil }
                // Full and we're not in it → space is full.
                if members.count >= 2 {
                    errorPointer?.pointee = NSError(domain: "Tweli.join", code: 409)
                    return nil
                }
                txn.updateData([
                    "memberUids": FieldValue.arrayUnion([uid]),
                    FieldPath(["memberNames", uid]): participantName,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
                return nil
            }
        } catch let e as NSError where e.domain == "Tweli.join" && e.code == 409 {
            log("join \(invite.spaceId): space full")
            throw PairCodeError.spaceFull
        } catch let e as NSError where e.domain == FirestoreErrorDomain
                    && e.code == FirestoreErrorCode.permissionDenied.rawValue {
            // Rules deny non-members reading a FULL space, so the transaction's
            // initial read hits PERMISSION_DENIED when both seats are taken —
            // that's "space is full", not a connectivity problem.
            log("join \(invite.spaceId): permission denied (space full or takeover)")
            throw PairCodeError.spaceFull
        } catch {
            log("join \(invite.spaceId) failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        setRole(.participant)
        setSpaceId(invite.spaceId)
        log("joined space \(invite.spaceId) as \(participantName)")
    }

    /// Write MY current profile name into the space doc's `memberNames` (allowed by
    /// the member-edit rule). Repairs a stale entry — e.g. the "You" placeholder
    /// written at createSpace time before the user filled in "About you" — so the
    /// partner's device shows the real name via its space-doc listener.
    func updateMyMemberName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "You",
              role != .none, !isDevOrOffline, let spaceId, let uid = currentUid else { return }
        defaults.set(trimmed, forKey: authNameKey)   // future pair codes carry it too
        do {
            try await db.collection("spaces").document(spaceId).updateData([
                FieldPath(["memberNames", uid]): trimmed,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            log("memberNames[\(uid)] = \(trimmed)")
        } catch {
            log("updateMyMemberName failed: \(error.localizedDescription)")
        }
    }

    /// Write MY IANA timezone into the space doc's `memberTimezones` map. The push
    /// Cloud Function reads the RECIPIENT's entry so it can respect quiet hours in
    /// their local time (silent delivery overnight). Same member-edit rule path as
    /// `updateMyMemberName` / `updateFCMToken` — a partial write of one map field.
    func updateMyTimezone() async {
        guard role != .none, !isDevOrOffline, let spaceId, let uid = currentUid else { return }
        let tz = TimeZone.current.identifier
        do {
            try await db.collection("spaces").document(spaceId).updateData([
                FieldPath(["memberTimezones", uid]): tz,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            log("memberTimezones[\(uid)] = \(tz)")
        } catch {
            log("updateMyTimezone failed: \(error.localizedDescription)")
        }
    }

    /// Date-only wire format for birthdays. A `Timestamp` would carry an instant,
    /// and a birthday read back in another zone can then land on the day before —
    /// the exact bug that makes a partner's nudge fire on the wrong date. A plain
    /// `yyyy-MM-dd` string has no zone to get wrong.
    static let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Write MY bio, city and birthday into the space doc so the partner's device
    /// can read them. These ride the same member-map pattern as `memberNames` and
    /// `memberTimezones`, and `isMemberEdit` in firestore.rules places no
    /// `hasOnly` restriction on the document's other keys — so this needs no rules
    /// change.
    ///
    /// Empty values are removed rather than written as "", so clearing a bio on
    /// one device actually clears it on the other.
    /// - Parameter allowClearing: whether an empty value may DELETE the stored
    ///   one. True when the user deliberately cleared a field; false when the
    ///   write is incidental (a launch-time push, a partial save), because a
    ///   device whose local copy is empty is not evidence the user wants the
    ///   remote copy gone. Without this, one reinstall silently erased a bio and
    ///   birthday from the partner's side too.
    func updateMyProfileDetails(bio: String?, city: String?, birthday: Date?,
                                allowClearing: Bool = false) async {
        guard role != .none, !isDevOrOffline, let spaceId, let uid = currentUid else { return }

        func entry(_ path: String, _ value: String?) -> (FieldPath, Any)? {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed?.isEmpty ?? true {
                guard allowClearing else { return nil }   // leave the stored value alone
                return (FieldPath([path, uid]), FieldValue.delete())
            }
            return (FieldPath([path, uid]), trimmed!)
        }

        var payload: [AnyHashable: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        for (path, value) in [entry("memberBios", bio),
                              entry("memberCities", city),
                              entry("memberBirthdays",
                                    birthday.map { Self.birthdayFormatter.string(from: $0) })]
            .compactMap({ $0 }) {
            payload[path] = value
        }
        // Nothing but the timestamp left — don't spend a write on it.
        guard payload.count > 1 else { return }

        do {
            try await db.collection("spaces").document(spaceId).updateData(payload)
            log("member profile details written for \(uid)")
        } catch {
            log("updateMyProfileDetails failed: \(error.localizedDescription)")
        }
    }

    /// Owner: the partner's display name once they've joined, or nil. Reads the
    /// `memberNames` map on the space doc (replaces the CKShare participant poll).
    /// The space-doc listener drives this live in normal operation; this shim covers
    /// a one-shot check.
    func acceptedParticipantName() async -> String? {
        guard role == .owner, !isDevOrOffline, let spaceId else { return nil }
        guard let snap = try? await db.collection("spaces").document(spaceId).getDocument(),
              let data = snap.data() else { return nil }
        let members = data["memberUids"] as? [String] ?? []
        guard members.count == 2 else { return nil }
        let names = data["memberNames"] as? [String: String] ?? [:]
        return names.first(where: { $0.key != currentUid })?.value ?? "Your partner"
    }

    // MARK: - Generic item CRUD (thin JSON payload)

    private func save<T: Codable>(_ item: T, id: UUID, type: String) async {
        guard role != .none, !isDevOrOffline, let spaceId else {
            log("save \(type) SKIPPED (role=\(role) devOrOffline=\(isDevOrOffline) space=\(spaceId ?? "nil"))")
            return
        }
        do {
            let data = try JSONEncoder().encode(item)
            guard let payload = String(data: data, encoding: .utf8) else { return }
            try await db.collection("spaces").document(spaceId)
                .collection(type).document(id.uuidString)
                .setData([
                    "payload": payload,
                    "authorUid": currentUid ?? "",
                    "updatedAt": FieldValue.serverTimestamp(),
                    "schemaVersion": 1
                ])
            log("save \(type) ok (\(id.uuidString.prefix(8)))")
        } catch {
            log("save \(type) failed: \(error.localizedDescription)")
        }
    }

    private func delete(id: UUID, type: String) async {
        guard role != .none, !isDevOrOffline, let spaceId else { return }
        do {
            try await db.collection("spaces").document(spaceId)
                .collection(type).document(id.uuidString).delete()
        } catch {
            log("delete \(type) failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync (remote → local)

    /// Everything the app merges from a remote change, grouped by record type, plus
    /// the ids that were deleted. Same shape as the CloudKit version so
    /// AppViewModel's decode + mergeRemote wiring is reused verbatim.
    struct RemoteChanges {
        /// Decoded payloads plus the uid that WROTE each one. `authorUid` is the
        /// Firebase uid and is stable across reinstalls; the `userId` inside the
        /// payload is a device-local UUID that is regenerated whenever the local
        /// profile is recreated. Distinguishing "mine" from "my partner's" on the
        /// payload id alone therefore breaks after a reinstall — your own older
        /// records start looking like theirs. Carrying the author lets the
        /// consumer settle it correctly.
        var payloadsByType: [String: [(data: Data, authorUid: String)]] = [:]     // keyed by RType
        var deletedIDs: [UUID] = []
        var partnerJoinedName: String? = nil           // set when the space doc shows member #2
        /// Set when the OTHER member removed themselves from the space (comp E6).
        var partnerLeftName: String? = nil
        /// The partner's IANA zone, read off `memberTimezones` on the space doc.
        /// Their device writes it on every sync, so this is available even when
        /// they have never shared a location.
        var partnerTimeZoneId: String? = nil
        /// The partner's own words, from `memberBios` (comp X5/X6).
        var partnerBio: String? = nil
        /// The city the partner TYPED (`memberCities`) — distinct from the
        /// reverse-geocoded `SharedLocation.cityLabel`, which only exists if they
        /// opted into location sharing.
        var partnerCity: String? = nil
        /// The partner's birthday from `memberBirthdays`, parsed from `yyyy-MM-dd`.
        var partnerBirthday: Date? = nil
    }

    /// Pull the partner's bio, city and birthday out of a raw space document.
    ///
    /// Deliberately a pure static function over `[String: Any]` rather than code
    /// inline in the snapshot closure: this is the half of the profile sync that
    /// decides whether anything the partner typed is ever seen, and a closure
    /// inside a Firestore listener cannot be tested without a live backend.
    /// Given a dictionary, it can.
    ///
    /// Absent keys stay nil, so a partner who filled nothing in reads as "not
    /// set" rather than as an empty string every view would have to special-case.
    /// `nonisolated` because it touches no instance state — it is a pure
    /// transform from a dictionary to three optionals. The enclosing type is
    /// `@MainActor`, which would otherwise force every caller (including tests)
    /// onto the main actor for no reason.
    nonisolated static func applyPartnerDetails(from data: [String: Any],
                                                partnerUid: String,
                                                into changes: inout RemoteChanges) {
        func value(_ key: String) -> String? {
            let map = data[key] as? [String: String] ?? [:]
            guard let raw = map[partnerUid] else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        changes.partnerBio = value("memberBios")
        changes.partnerCity = value("memberCities")
        changes.partnerBirthday = value("memberBirthdays")
            .flatMap { birthdayFormatter.date(from: $0) }
    }

    /// Attach live listeners on the space doc + all six item subcollections (7
    /// total). Each item snapshot delivers added/modified payloads and `.removed`
    /// deletions; the space-doc listener surfaces "partner joined". The callback
    /// hands back a RemoteChanges in the same shape AppViewModel already merges.
    func startListening(onChange: @escaping (RemoteChanges) -> Void) {
        guard !isDevOrOffline, let spaceId else { return }
        stopListening()
        let spaceRef = db.collection("spaces").document(spaceId)

        for type in RType.all {
            let reg = spaceRef.collection(type).addSnapshotListener { snapshot, error in
                guard let snapshot else {
                    if let error {
                        self.log("listener \(type) error: \(error.localizedDescription)")
                        self.reportIfFatal(error)
                    }
                    return
                }
                var changes = RemoteChanges()
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added, .modified:
                        if let payload = change.document["payload"] as? String,
                           let data = payload.data(using: .utf8) {
                            let author = change.document["authorUid"] as? String ?? ""
                            changes.payloadsByType[type, default: []]
                                .append((data: data, authorUid: author))
                        }
                    case .removed:
                        if let uuid = UUID(uuidString: change.document.documentID) {
                            changes.deletedIDs.append(uuid)
                        }
                    @unknown default:
                        break
                    }
                }
                if !changes.payloadsByType.isEmpty || !changes.deletedIDs.isEmpty {
                    onChange(changes)
                }
            }
            listeners.append(reg)
        }

        let spaceReg = spaceRef.addSnapshotListener { snapshot, error in
            if let error { self.reportIfFatal(error) }
            guard let data = snapshot?.data() else { return }
            let members = data["memberUids"] as? [String] ?? []
            let names = data["memberNames"] as? [String: String] ?? [:]
            var changes = RemoteChanges()

            // The partner walked out: they removed themselves and stamped
            // `leftBy`. We're the only member left, and the uid on the stamp is
            // not ours (a stale marker from our OWN earlier departure must not
            // raise E6 on a space we later rejoined).
            if let leftBy = data["leftBy"] as? String,
               leftBy != self.currentUid,
               members.count == 1, members.first == self.currentUid {
                changes.partnerLeftName = names[leftBy] ?? "Your partner"
                onChange(changes)
                return
            }

            guard members.count == 2 else { return }
            let partnerUid = members.first { $0 != self.currentUid }
            let partnerName = names.first(where: { $0.key != self.currentUid })?.value ?? "Your partner"
            changes.partnerJoinedName = partnerName
            // The same doc already carries each member's zone for the push
            // function's quiet hours; hand it to the client too.
            if let partnerUid {
                let zones = data["memberTimezones"] as? [String: String] ?? [:]
                changes.partnerTimeZoneId = zones[partnerUid]
                Self.applyPartnerDetails(from: data, partnerUid: partnerUid, into: &changes)
            }
            onChange(changes)
        }
        listeners.append(spaceReg)
        log("started \(listeners.count) listeners on space \(spaceId)")
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    /// Only permission-denied and not-found are fatal. Everything else — most
    /// importantly `.unavailable` — is a network condition the offline cache
    /// already absorbs, and must not raise the failure screen.
    private func reportIfFatal(_ error: Error) {
        let code = FirestoreErrorCode.Code(rawValue: (error as NSError).code)
        switch code {
        case .permissionDenied:
            fatalSyncError = "We can't reach your shared space right now."
        case .notFound:
            fatalSyncError = "That shared space no longer exists."
        default:
            break
        }
    }

    /// Comp E8 "Try again" — clear the failure and re-attach the listeners.
    func clearFatalSyncError() { fatalSyncError = nil }

    /// One-shot pull of the current item set (pull-to-refresh / first sync before
    /// listeners settle). Listener-independent.
    func fetchChanges() async -> RemoteChanges {
        guard !isDevOrOffline, let spaceId else { return .init() }
        var out = RemoteChanges()
        let spaceRef = db.collection("spaces").document(spaceId)
        for type in RType.all {
            guard let snapshot = try? await spaceRef.collection(type).getDocuments() else { continue }
            for doc in snapshot.documents {
                if let payload = doc["payload"] as? String, let data = payload.data(using: .utf8) {
                    let author = doc["authorUid"] as? String ?? ""
                    out.payloadsByType[type, default: []].append((data: data, authorUid: author))
                }
            }
        }
        return out
    }

    // MARK: - Push (FCM token storage; background push deferred to Blaze)

    /// On Spark this means "obtain + store the FCM token" — there is no server
    /// subscription (that needs a Cloud Function on the Blaze plan). Wired so a
    /// future Blaze function is a pure add.
    func registerForPush() async {
        guard !isDevOrOffline else { return }
        if let token = try? await Messaging.messaging().token() {
            await updateFCMToken(token)
        }
    }

    /// Store this device's FCM token on the space doc (`fcmTokens[uid]`). The only
    /// piece a future background-push Cloud Function needs.
    func updateFCMToken(_ token: String) async {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { return }
        do {
            try await db.collection("spaces").document(spaceId).updateData([
                FieldPath(["fcmTokens", uid]): token
            ])
            log("stored FCM token for \(uid)")
        } catch {
            log("updateFCMToken failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset

    /// Detach listeners and clear local role/spaceId/cached code. "Leave space" is
    /// local-only: the security rules forbid removing a member or deleting the
    /// space, so no remote write is attempted — the space stays intact for the
    /// partner.
    /// Remove myself from the shared space and stamp the departure so the other
    /// device can show comp E6. Items are deliberately left in place — the copy
    /// promises "everything you wrote together is safe for 30 days", and a
    /// client-side purge would break that promise the moment it ran.
    ///
    /// Best-effort: if the write fails (offline, or the rule rejects it) we
    /// still tear down locally, because refusing to let someone leave is worse
    /// than the partner learning about it late.
    func announceLeave() async {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { return }
        do {
            try await db.collection("spaces").document(spaceId).updateData([
                "memberUids": FieldValue.arrayRemove([uid]),
                "fcmTokens.\(uid)": FieldValue.delete(),
                // Your bio, city and birthday go with you. `memberNames` stays
                // on purpose — comp E6 needs the name to say who left — but
                // there is no reason the rest should linger in a space you are
                // no longer part of. `isMemberLeave` puts no `hasOnly` guard on
                // these keys, so removing them here is permitted.
                "memberBios.\(uid)": FieldValue.delete(),
                "memberCities.\(uid)": FieldValue.delete(),
                "memberBirthdays.\(uid)": FieldValue.delete(),
                "leftBy": uid,
                "leftAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            log("announced leave of space \(spaceId)")
        } catch {
            log("announceLeave failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Account deletion

    /// The deployed `deleteAccount` HTTP function. Region must match
    /// `setGlobalOptions({ region })` in functions/index.js.
    private var deleteAccountURL: URL? {
        guard let projectId = FirebaseApp.app()?.options.projectID else { return nil }
        return URL(string: "https://asia-south1-\(projectId).cloudfunctions.net/deleteAccount")
    }

    /// Apple requires the Sign in with Apple token to be revoked when an account
    /// is deleted. Firebase does the exchange given a fresh authorization code.
    func revokeAppleToken(authorizationCode: String) async throws {
        guard !isDevOrOffline else { return }
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
        log("revoked Apple token")
    }

    /// Permanently destroys the account server-side: everything this user
    /// authored, their membership, their invite codes, and the Auth user itself.
    ///
    /// Deliberately server-side — Firestore has no recursive client delete, and
    /// admin `deleteUser` needs no recent login. See functions/index.js.
    /// - Parameter keepLetters: comp W3's "Deliver my sealed letters first".
    ///   When true, letters you wrote are unsealed and EXEMPTED from deletion so
    ///   they stay your partner's to keep. Default false, which preserves the
    ///   shipped behaviour of removing everything you authored.
    func deleteAccount(keepLetters: Bool = false) async throws {
        guard !isDevOrOffline else {
            // A dev session has nothing on the server to remove.
            reset()
            return
        }
        guard let url = deleteAccountURL else { throw AccountDeletionError.notConfigured }
        guard let user = Auth.auth().currentUser else { throw AccountDeletionError.notSignedIn }

        let idToken = try await user.getIDToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["keepLetters": keepLetters])
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            log("deleteAccount HTTP \(status): \(body)")
            throw AccountDeletionError.server(status)
        }
        log("account deleted server-side")

        // The Auth user is gone; drop the local session so nothing retries with
        // a token for a user that no longer exists.
        try? signOut()
        reset()
    }

    enum AccountDeletionError: LocalizedError {
        case notConfigured, notSignedIn, server(Int)
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Account deletion isn't available in this build."
            case .notSignedIn:
                return "You're not signed in."
            case .server:
                return "We couldn't delete your account just now. Please check your connection and try again."
            }
        }
    }

    func reset() {
        stopListening()
        setRole(.none)
        setSpaceId(nil)
        defaults.removeObject(forKey: pairCodeKey)
        defaults.removeObject(forKey: pairCodeExpiryKey)
        pairCodeExpiresAt = nil
    }

    private func log(_ msg: String) { print("[Firebase] \(msg)") }

    // MARK: - Typed wrappers (called by the feature services — unchanged signatures)

    func createCoupleSpace(_ space: CoupleSpace) async { /* space is created via createSpace() from the UI */ }

    func saveReminder(_ r: ReminderItem) async { await save(r, id: r.id, type: RType.reminder) }
    func deleteReminder(_ r: ReminderItem) async { await delete(id: r.id, type: RType.reminder) }

    func saveCountdown(_ c: CountdownItem) async { await save(c, id: c.id, type: RType.countdown) }
    func deleteCountdown(_ c: CountdownItem) async { await delete(id: c.id, type: RType.countdown) }

    func saveLetter(_ l: OpenWhenLetter) async { await save(l, id: l.id, type: RType.letter) }
    func saveVirtualDate(_ d: VirtualDateItem) async { await save(d, id: d.id, type: RType.virtualDate) }
    func saveMood(_ m: MoodStatus) async { await save(m, id: m.id, type: RType.mood) }
    func sendPing(_ p: MissingYouPing) async { await save(p, id: p.id, type: RType.ping) }
    func saveLocation(_ l: SharedLocation) async { await save(l, id: l.id, type: RType.location) }
    func deleteLocation(_ l: SharedLocation) async { await delete(id: l.id, type: RType.location) }
}
