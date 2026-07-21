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
//  uid, so debug builds run entirely on MockData + local stores. Compile-time
//  excluded from release builds.
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
    /// returns on this so debug builds stay fully offline on MockData.
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
    /// as offline, so all Firestore reads/writes/listeners short-circuit (mirrors
    /// the old CloudKit DEBUG path that ran on MockData with role == .none).
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

    /// Unambiguous alphabet — no 0/O, 1/I/L. 6 chars ≈ 887M combinations.
    static let codeAlphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")

    private static func makeCode() -> String {
        String((0..<6).map { _ in codeAlphabet.randomElement()! })
    }

    /// Uppercases and strips separators so "7gk-4pb" and "7GK 4PB" both work.
    static func normalizePairCode(_ raw: String) -> String {
        raw.uppercased().filter { codeAlphabet.contains($0) }
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

    /// Owner: publish (or reuse an unexpired) 6-char pair code pointing at this
    /// space. The code IS the document id, so redemption is a direct getDocument —
    /// no query index, no dashboard setup.
    func publishPairCode(spaceTitle: String) async throws -> String {
        guard !isDevOrOffline, let spaceId, let uid = currentUid else { throw PairCodeError.network }

        // Reuse a previously published, unexpired code so re-visits show the same one.
        if let cached = defaults.string(forKey: pairCodeKey),
           let doc = try? await db.collection("pairCodes").document(cached).getDocument(),
           doc.exists,
           let expires = (doc["expiresAt"] as? Timestamp)?.dateValue(), expires > Date() {
            log("reusing pair code \(cached)")
            return cached
        }

        let code = Self.makeCode()
        do {
            try await db.collection("pairCodes").document(code).setData([
                "spaceId": spaceId,
                "spaceTitle": spaceTitle,
                "createdBy": uid,
                "createdByName": displayName,
                "expiresAt": Timestamp(date: Date().addingTimeInterval(48 * 3600)),  // 48h
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            log("publishPairCode failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        defaults.set(code, forKey: pairCodeKey)
        log("published pair code \(code) → space \(spaceId)")
        return code
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
        } catch {
            log("join \(invite.spaceId) failed: \(error.localizedDescription)")
            throw PairCodeError.network
        }
        setRole(.participant)
        setSpaceId(invite.spaceId)
        log("joined space \(invite.spaceId) as \(participantName)")
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
        guard role != .none, !isDevOrOffline, let spaceId else { return }
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
        var payloadsByType: [String: [Data]] = [:]     // keyed by RType
        var deletedIDs: [UUID] = []
        var partnerJoinedName: String? = nil           // set when the space doc shows member #2
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
                    if let error { self.log("listener \(type) error: \(error.localizedDescription)") }
                    return
                }
                var changes = RemoteChanges()
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added, .modified:
                        if let payload = change.document["payload"] as? String,
                           let data = payload.data(using: .utf8) {
                            changes.payloadsByType[type, default: []].append(data)
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
            guard let data = snapshot?.data() else { return }
            let members = data["memberUids"] as? [String] ?? []
            guard members.count == 2 else { return }
            let names = data["memberNames"] as? [String: String] ?? [:]
            let partnerName = names.first(where: { $0.key != self.currentUid })?.value ?? "Your partner"
            var changes = RemoteChanges()
            changes.partnerJoinedName = partnerName
            onChange(changes)
        }
        listeners.append(spaceReg)
        log("started \(listeners.count) listeners on space \(spaceId)")
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

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
                    out.payloadsByType[type, default: []].append(data)
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
    func reset() {
        stopListening()
        setRole(.none)
        setSpaceId(nil)
        defaults.removeObject(forKey: pairCodeKey)
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
