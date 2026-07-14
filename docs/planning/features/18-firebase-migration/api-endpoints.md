# API / Service Spec — Firebase Migration

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Date**: 2026-07-11
**Agent**: @api-design-architect

There is no REST backend. The "API" here is the Swift service layer wrapping the
Firebase iOS SDK (Firestore + Firebase Auth + FCM). This document specifies the
public surface of the new `FirebaseService` — a drop-in replacement for
`CloudKitService` at the single backend boundary — plus the Sign in with Apple
→ Firebase Auth flow, the pair-code invite operations, the snapshot-listener sync
design, the FCM approach (and what forces the Blaze plan), the SPM dependency
list, and the Firebase console prerequisites the user must complete by hand.

The overriding compatibility rule: **feature services and Room views call the
same method names, static helpers, and nested types they call on `CloudKitService`
today.** Anything that cannot survive the cutover unchanged (the CKShare-based
redeem return, `PendingInvite`) is called out explicitly under
"Caller migration impact" so the UI planner can absorb it.

---

## Identity model (read this first — it shapes everything below)

Two distinct identities coexist and must not be conflated:

| Identity | Type | Source | Used for |
|---|---|---|---|
| **Firebase UID** | `String` | Firebase Auth (Apple credential exchange) | Space membership (`memberUids`), pair-code `createdBy`, **security-rule enforcement** |
| **App profile id** | `UUID` | `UserProfile.id`, generated per install | Model payload identity (`Mood.sentBy`, `Ping.sentTo`, reminder ownership) — **unchanged** |

The item payloads (Reminder, Mood, Ping, …) keep their existing `UUID` fields
encoded verbatim as JSON blobs, exactly as today. The Firebase UID never enters a
payload; it lives only on the `spaces/{spaceId}` document and `pairCodes/{code}`
document, where Firestore security rules can read it. This keeps R2's "thin
payload blob" mapping intact and means `mergeRemote(_:deletedIDs:)` on every
feature service is untouched.

`FirebaseService.currentUid` (`String?`) exposes the signed-in Firebase UID for
membership operations. The composition root keeps stamping model UUIDs exactly as
`AppViewModel.wireIdentities()` does now.

---

## FirebaseService — full public surface

`@MainActor final class FirebaseService: ObservableObject`. Mirrors
`CloudKitService`'s surface; new members marked **(new)**, renamed/changed members
marked **(changed)**.

### Config, role, lifecycle

```swift
// Nested types callers reach into today — KEEP THESE NAMES.
enum Role: String { case none, owner, participant }
enum RType {                                   // record/collection type names
    static let reminder = "reminders", countdown = "countdowns", letter = "letters"
    static let virtualDate = "virtualDates", mood = "moods", ping = "pings"
}

@Published private(set) var role: Role
@Published private(set) var accountAvailable: Bool   // (changed) = "a Firebase user is signed in", NOT iCloud status

var currentUid: String? { get }                       // (new) Firebase Auth UID
private(set) var spaceId: String?                     // (new) the couple's space doc id, cached in UserDefaults

init()                                                // reads persisted role + spaceId; configures Firestore persistence
func refreshAccountStatus() async                     // (changed) reflects Firebase Auth state, never CKError.quotaExceeded
```

`RType` values change from PascalCase record types (`"Reminder"`) to plural
collection names (`"reminders"`) because they now name Firestore subcollections.
`AppViewModel.syncNow()`/listener wiring reads these constants symbolically, so the
string values can change safely — grep confirms no literal `"Reminder"` outside the
`RType` enum. **Coordinate the exact strings with database.md** so collection paths
match; this doc assumes the plural names above.

### Auth integration (see "Sign in with Apple" section for the flow)

```swift
// Exchange a verified Apple credential for a Firebase session. Called by AuthService
// from the SignInWithAppleButton completion. Returns the Firebase UID + best-known
// display name so AuthService can persist them exactly as it does today.
func signInWithApple(idToken: String, rawNonce: String,
                     fullName: PersonNameComponents?) async throws -> FirebaseUser   // (new)

func signOut() throws                                  // (new) Firebase Auth sign-out; clears role + spaceId

struct FirebaseUser { let uid: String; let displayName: String }   // (new)

#if DEBUG
func devSignIn()                                       // (new) offline mock — no network (see bypass section)
#endif
```

### Space + pairing (invite flow — R3)

```swift
// Owner: create the couple space document and become owner. Replaces createShare().
// Returns the new spaceId. No server round-trip, no URL minting wait.
func createSpace(title: String) async throws -> String                 // (changed, was createShare -> CKShare)

// Owner: publish (or reuse an unexpired) 6-char pair code pointing at this space.
// Mirrors publishPairCode; no shareURL argument — the code points at spaceId.
func publishPairCode(spaceTitle: String) async throws -> String        // (changed signature)

// Partner: resolve a typed/deep-linked code into invite metadata for the confirm sheet.
// Returns a plain struct instead of CKShare.Metadata (no CloudKit type).
func redeemPairCode(_ raw: String) async throws -> PairInvite          // (changed return type)

// Partner: atomically join the space named by a redeemed PairInvite. Enforces
// max-2 membership and no takeover, in a Firestore transaction AND security rules.
func joinSpace(_ invite: PairInvite, participantName: String) async throws   // (new; replaces acceptShare)

// Owner: the partner's display name once they've joined, or nil. Backed by the
// space-doc listener (see sync) rather than a poll.
func acceptedParticipantName() async -> String?                        // (unchanged signature)

// Static helpers callers use directly — KEEP as static on FirebaseService.
static func normalizePairCode(_ raw: String) -> String                 // identical impl to today
static let codeAlphabet: [Character]                                    // identical: "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

// Error taxonomy — SAME copy as today (see "Error taxonomy" below).
enum PairCodeError: LocalizedError { case notFound, expired, badShareURL, spaceFull, network }   // (changed: drop shareURLNotReady, add spaceFull)

struct PairInvite: Identifiable {                                       // (new) replaces CKShare.Metadata for the confirm sheet
    let spaceId: String
    let spaceTitle: String
    let inviterName: String
    var id: String { spaceId }
}
```

### Item CRUD — typed wrappers (unchanged call sites)

Every feature service keeps calling these exact signatures:

```swift
func createCoupleSpace(_ space: CoupleSpace) async   // stays a no-op; space is created via createSpace()

func saveReminder(_ r: ReminderItem) async
func deleteReminder(_ r: ReminderItem) async
func saveCountdown(_ c: CountdownItem) async
func deleteCountdown(_ c: CountdownItem) async
func saveLetter(_ l: OpenWhenLetter) async
func saveVirtualDate(_ d: VirtualDateItem) async
func saveMood(_ m: MoodStatus) async
func sendPing(_ p: MissingYouPing) async
```

Internally, `save<T: Codable>(_:id:type:)` and `delete(id:)` write/remove a document
at `spaces/{spaceId}/{type}/{uuid}` with the Codable JSON stored in a `payload`
field — identical modeling to CloudKit's `payload` blob, so mapping stays trivial.
Each `save` also stamps `updatedAt: FieldValue.serverTimestamp()` and
`authorUid: currentUid` (needed by security rules and future push). All are
no-ops when `role == .none` or `spaceId == nil`, matching today's guard.

### Sync — snapshot listeners (replaces fetchChanges + change tokens — R4)

```swift
// Attach live listeners on the space doc + all six item subcollections. Each item
// snapshot delivers added/modified/removed doc changes; the callback hands decoded
// payloads and deleted UUIDs back in the SAME shape AppViewModel already merges.
func startListening(onChange: @escaping (RemoteChanges) -> Void)       // (new; replaces fetchChanges)
func stopListening()                                                   // (new) detach all listeners

// Same struct name/shape as today so the decode+merge wiring in AppViewModel.syncNow
// is reused almost verbatim.
struct RemoteChanges {
    var payloadsByType: [String: [Data]] = [:]     // keyed by RType
    var deletedIDs: [UUID] = []
    var partnerJoinedName: String? = nil           // (new) set when the space-doc listener sees member #2
}

// Back-compat shim so a one-shot pull still exists (used by manual "pull to refresh"
// or the first sync before listeners settle). Wraps a single getDocuments per type.
func fetchChanges() async -> RemoteChanges                             // (kept, now listener-independent)
```

### Push (R5) + reset

```swift
func registerForPush() async                          // (changed, was registerSubscription) — see FCM section
func updateFCMToken(_ token: String) async            // (new) store this device's FCM token on the member profile
func reset()                                          // detach listeners, clear role/spaceId/cached keys, optional leave
```

---

## Sign in with Apple → Firebase Auth (R1)

The existing `AuthService` UX is preserved: same `SignInWithAppleButton`, same
`configure(_:)` requesting `.fullName` + `.email`, same UserDefaults persistence of
user id + display name. Only the credential handling changes — after Apple returns a
credential, we exchange it for a Firebase session using the nonce flow.

**Nonce flow (why it exists):** Firebase requires proof that the Apple ID token was
minted for *this* sign-in request, to prevent replay. You generate a random nonce,
send its **SHA-256 hash** to Apple in the authorization request, and send the
**raw** nonce to Firebase alongside Apple's ID token. Firebase re-hashes the raw
nonce and checks it against the hash embedded in the signed token.

Sequence:

1. `AuthService.configure(request:)` — generate a cryptographically random
   `rawNonce` (32 bytes, `SecRandomCopyBytes`), stash it, set
   `request.nonce = sha256(rawNonce)` in addition to today's
   `requestedScopes = [.fullName, .email]`.
2. On success, extract from `ASAuthorizationAppleIDCredential`:
   `identityToken` (Data → UTF-8 String) and `fullName` (first sign-in only).
3. Call `FirebaseService.signInWithApple(idToken:rawNonce:fullName:)`, which builds
   `OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce,
   fullName: fullName)` and calls `Auth.auth().signIn(with: credential)`.
4. On success, persist `uid` + display name exactly as `store(userId:name:)` does
   today (display name from Apple's `fullName` on first auth, else the persisted
   name, else the `"You"` fallback). The Firebase UID is the canonical membership id;
   the local UserProfile UUID is untouched.
5. `accountAvailable` becomes `Auth.auth().currentUser != nil`. On cold launch,
   `init()` reads `Auth.auth().currentUser` (Firebase persists the session in
   Keychain automatically — this also satisfies the AuthService TODO about moving
   the user id off UserDefaults).

**Console dependency:** the native iOS Sign in with Apple flow needs only the
**Apple provider enabled** in Firebase Auth. Because we exchange the credential
natively (not via web redirect), the Services ID / private-key / redirect-URL setup
that Firebase's web flow requires is **not** needed, as long as the app's bundle id
`me.adithyan.shalinth.Tweli` matches the Firebase iOS app. (See prerequisites.)

### DEBUG auth bypass — kept working, still no network

Project convention: debug builds land authenticated with a mock session and make no
network call. Preserve this exactly:

```swift
#if DEBUG
func devSignIn() {
    // No Firebase call. Set a synthetic uid so downstream code has a non-nil identity.
    // FirebaseService treats a "dev-" uid as offline: all Firestore reads/writes and
    // listeners short-circuit (mirrors today, where DEBUG uses MockData + role=none).
    self.currentUid = "dev-\(UUID().uuidString)"
    self.accountAvailable = true
}
#endif
```

`FirebaseService` gates every network operation on
`currentUid != nil && currentUid?.hasPrefix("dev-") == false`. In DEBUG the app runs
entirely on `MockData` + local stores, precisely as it does now with CloudKit
`role == .none`. This keeps `#if DEBUG` compile-time exclusion from release builds.

**Optional (documented, not default):** if you want to exercise *real* Firestore
sync in the simulator, an alternate debug path can call
`Auth.auth().signInAnonymously()` to obtain a real UID. This is offered as an opt-in
(`devSignInWithRealSync()`), left off by default to honor the "no network" rule.

---

## Space creation + pair code publish / redeem / join (R3)

The CloudKit invite dance (create zone → save CKShare → poll for server-minted URL →
publish code → fetch share metadata → accept share) collapses dramatically because
Firestore writes are immediate and the invite carries only a `spaceId`.

### Create (owner)

`createSpace(title:)` writes `spaces/{spaceId}` (auto-id) with:
`title`, `ownerUid = currentUid`, `memberUids = [ownerUid]`,
`memberNames = [currentUid: displayName]`, `createdAt = serverTimestamp()`.
(Display names live only in the `memberNames` map — no scalar name fields — matching
the database.md §2.1 schema and the `isMemberEdit` rule.) Sets `role = .owner`, caches `spaceId`. Returns the
id. No URL to wait for — the `preparingShare`/`shareWithURL` backoff polling in
`CreateSpaceView.createInviteLink()` is deleted; the button becomes near-instant.

**Shareable link (replaces the CKShare `.url`):** built purely client-side once the
pair code exists. Recommended primary form is a **Firebase Hosting universal link**
(free on Spark):

```
https://<project-id>.web.app/join?code=7GK4PB      // universal link → opens app, or App Store if not installed
```

with `tweli://join?code=7GK4PB` as the always-present fallback and the 6-char code as
the human-readable path. The universal link is what WhatsApp/iMessage will linkify
(they don't linkify `tweli://`). See "Assumptions" for the Hosting decision and the
zero-cost code-only fallback if Hosting is skipped for MVP.

### Publish code (owner)

`publishPairCode(spaceTitle:)` — reuse a cached, unexpired code if present
(`tweli.pairCode` UserDefaults key), else generate a 6-char code from the **identical
alphabet** (`23456789ABCDEFGHJKMNPQRSTUVWXYZ` — no 0/O/1/I/L) and write
`pairCodes/{code}`: `spaceId`, `spaceTitle`, `createdBy = ownerUid`,
`createdByName = displayName`, `expiresAt = now + 48h`. The code **is** the document
id, so redemption is a direct `getDocument` — no query index, no dashboard setup,
matching today's "code as record name" trick. Returns the code.

### Redeem (partner)

`redeemPairCode(_ raw:)`:

1. `normalizePairCode(raw)` — same uppercase + strip-non-alphabet normalization, so
   `7gk-4pb` and `7GK 4PB` both resolve.
2. `getDocument(pairCodes/{code})`.
3. Missing doc → `.notFound`. Any other read failure (network/permission/offline) →
   `.network` — never `.notFound`, because telling a user a valid code is wrong makes
   them give up (this nuance is copied verbatim from the CloudKit implementation).
4. `expiresAt < now` → `.expired`.
5. Missing/blank `spaceId` → `.badShareURL` (kept for the "invite looks broken" copy).
6. Return `PairInvite(spaceId:, spaceTitle:, inviterName: createdByName ?? "Your partner")`.

`inviterName` now comes from the `createdByName` we stored at publish time, replacing
CloudKit's `ownerIdentity.nameComponents` — this preserves the "Owner sees partner's
name / partner sees inviter's name" parity without needing an iCloud identity.

### Join (partner)

`joinSpace(_:participantName:)` runs a Firestore transaction on `spaces/{spaceId}`:

- Re-read the doc; if `memberUids.count >= 2` and `currentUid` isn't already in it →
  throw `PairCodeError.spaceFull` (distinct case with its own copy — see the error
  taxonomy; today no full-space case existed because CKShare handled it).
- Else `arrayUnion(currentUid)` into `memberUids` and set
  `memberNames[currentUid] = participantName` (the only two fields `isMemberEdit`
  permits the joiner to touch — no scalar `participantUid`/`participantName` fields).
- Set `role = .participant`, cache `spaceId`, start listeners.

The **security rules** independently enforce max-2 and no-takeover (a member can be
added only if the writer is that new member and `memberUids.size() <= 2` and no
existing uid is removed). Rules are the real guard; the transaction is the friendly
path. Detailed rules live in database.md.

### Error taxonomy — mirrors today's `PairCodeError` copy

Reuse the exact user-facing strings so no copy changes:

| Case | Trigger (Firebase) | Copy (unchanged) |
|---|---|---|
| `notFound` | `pairCodes/{code}` doc missing | "That code wasn't found. Double-check it, or ask your partner for a fresh one." |
| `expired` | `expiresAt < now` | "That code has expired. Ask your partner to create a new invite." |
| `badShareURL` | missing/blank `spaceId` on the pair-code doc | "This invite looks broken. Ask your partner to create a new one." |
| `spaceFull` *(new)* | join transaction finds `memberUids.count == 2` already | "This space already has two people. Ask your partner to send you a fresh invite." |
| `network` | any non-missing read/transaction failure | "Couldn't check the code right now. Check your connection and try again." |

`shareURLNotReady` is **removed** — it existed only because CloudKit minted the share
URL asynchronously; Firestore writes are synchronous so the state can't occur.

---

## Snapshot-listener sync design (R4)

Change tokens and manual delta fetch are replaced by Firestore snapshot listeners,
which push live changes and, critically, deliver **deletions** as `.removed` document
changes — so deletion propagation is native rather than bolted on.

**Listener set** (attached in `startListening`, detached in `stopListening`/`reset`):

- One listener per item subcollection: `spaces/{spaceId}/reminders`, `/countdowns`,
  `/letters`, `/virtualDates`, `/moods`, `/pings`.
- One listener on the space doc `spaces/{spaceId}` (drives owner's "partner joined"
  and any title change).

**Per-snapshot handling** (item collections): iterate
`snapshot.documentChanges`:

- `.added` / `.modified` → append `document["payload"] as? Data` (or re-encode the
  decoded map) into `RemoteChanges.payloadsByType[RType]`.
- `.removed` → `UUID(uuidString: document.documentID)` into `deletedIDs`.

The callback hands a `RemoteChanges` to `AppViewModel`, whose existing
`decode(_:)` + `mergeRemote(_:deletedIDs:)` wiring consumes it **unchanged**. The
first snapshot after attach includes the full current set (fromCache first if
offline, then server) — this replaces the initial `fetchChanges()` pull.

**Space-doc handling:** when the snapshot shows `memberUids.count == 2`, read the
partner's name from the `memberNames` map (the entry whose key ≠ `currentUid`,
falling back to "Your partner") and set `RemoteChanges.partnerJoinedName` so `AppViewModel` calls
`coupleSpaceService.setPartnerJoined(name:)` — replacing the owner-side
`acceptedParticipantName()` poll in `syncNow()`.

**Metadata / echo suppression:** attach listeners with
`includeMetadataChanges = false` (default) so we don't process local-write echoes.
Firestore's `hasPendingWrites` flag can additionally be checked to skip a device's
own optimistic writes — the feature services already de-dupe by id in `mergeRemote`,
so this is belt-and-suspenders.

**Offline (R4):** enable Firestore local persistence
(`FirestoreSettings.cacheSettings = PersistentCacheSettings()`, default enabled on
iOS). Writes queue offline and replay on reconnect; listeners serve from cache first.
This matches the current "local store stays authoritative when the backend is off"
behavior, and — unlike CloudKit — never fails on the user's personal storage quota,
which is the entire reason for this migration.

**Wiring change in `AppViewModel`:** `syncNow()` shrinks to "start listeners once +
`refreshWidget()` on each callback." The silent-push path (`onRemoteChange`) becomes
a redundant nudge rather than the primary sync trigger, because listeners already
keep an active app current.

---

## FCM integration approach (R5) — and the Blaze boundary

The hard constraint: **server-side push on Firestore triggers requires Cloud
Functions, which require the Blaze (pay-as-you-go) plan.** Cross-device background
delivery therefore cannot be fully implemented on Spark. The design degrades
cleanly and pre-wires everything so enabling Blaze later is a pure add.

**What ships on Spark (free) for MVP:**

- **FCM token registration.** Add the `FirebaseMessaging` SDK, register for APNs
  (`registerForRemoteNotifications`, already called in `AppDelegate`), and on
  `messaging(_:didReceiveRegistrationToken:)` call
  `FirebaseService.updateFCMToken(_:)`, which writes the token into the `fcmTokens`
  map on the space doc (`spaces/{spaceId}` field `fcmTokens[uid] = token` — the
  standardized location; a `members/{uid}` subcollection would be blocked by the
  rules and is not used). Free, and it's the only piece a future Cloud
  Function needs.
- **Live delivery via snapshot listeners.** While the partner's app is foregrounded
  (or backgrounded with the system briefly keeping the listener alive), a new
  `pings` doc arrives through the listener and the "Send love" UX updates in real
  time. This is the MVP delivery mechanism.
- **Local notifications** continue for the reminder/countdown UX (already handled by
  `ReminderNotificationService`) — these are on-device and unaffected.

**What is deferred to Blaze (flag, don't build):**

- A Cloud Function `onCreate` trigger on `spaces/{spaceId}/pings/{id}` (and other
  item collections) that sends an FCM data/notification message to the *other*
  member's stored token → true background/killed-app wake, full parity with the
  CloudKit zone subscription's silent push.
- **Do not** attempt client-to-client FCM sends: the HTTP v1 send API needs a
  service-account credential that must never ship in the app, and the legacy
  server-key send-from-client path is removed. There is no secure Spark-only way to
  send a push from one device to another.

`registerForPush()` therefore, on Spark, means "obtain + store the FCM token"; it
does **not** create any server subscription. `AppDelegate.didReceiveRemoteNotification`
stays wired so that the day a Blaze function starts sending pushes, the existing
`onRemoteChange` → `syncNow()` path lights up with no client change.

**Explicitly flagged as Blaze-required:** any server-sent push (background ping
delivery, wake-on-change when the app is killed). MVP acceptance is: live sync when
active + local notifications; background cross-device push is a documented follow-up.

---

## SPM dependencies

Add **firebase-ios-sdk** (`https://github.com/firebase/firebase-ios-sdk`), pin to
the latest **v11.x** (`.upToNextMajor(from: "11.0.0")`). Link these products to the
**main app target only**:

| Product | Purpose |
|---|---|
| `FirebaseCore` | SDK bootstrap (`FirebaseApp.configure()`) |
| `FirebaseAuth` | Sign in with Apple credential exchange, session persistence |
| `FirebaseFirestore` | Documents, subcollections, snapshot listeners, offline cache. Codable support (`Firestore.Decoder`/`Encoder`) is built into `FirebaseFirestore` in v11 — the separate `FirebaseFirestoreSwift` product is deprecated/absorbed; **do not add it**. |
| `FirebaseMessaging` | FCM token registration (token storage now; server push later on Blaze) |

**Widget target (`TweliWidget`): link none of the above.** Per R7 the widget reads
shared local data via the App Group (`WidgetDataService` + `WidgetSnapshot`), with no
CloudKit or Firestore dependency — verify the handoff path stays local-only. Keeping
Firebase out of the widget avoids extension bloat and a second
`GoogleService-Info.plist`.

---

## User-facing prerequisites (Firebase console + Xcode — must be done by hand)

These block the build/runtime and cannot be scripted from here. Present as an
explicit checklist to the user:

1. **Create the Firebase project** (or reuse the user's existing account) at
   console.firebase.google.com. Keep it on the **Spark (free)** plan.
2. **Register the iOS app**: bundle id **`me.adithyan.shalinth.Tweli`**. (The widget
   extension does **not** need registering — it isn't a Firebase client.)
3. **Download `GoogleService-Info.plist`** and add it to the **app target** (Build
   Phases → Copy Bundle Resources). Not to the widget target. Recommend adding it to
   `.gitignore` (not secret, but conventional) and documenting where teammates get it.
4. **Enable Authentication → Sign-in method → Apple** (provider toggle on). Native
   flow needs nothing further as long as the bundle id matches; no Services ID / key
   setup required.
5. **Create Firestore Database** (Native mode). Choose a region close to users
   (e.g. `us-central` or an EU region) — region is permanent.
6. **Deploy Firestore security rules** from database.md (only the 2 member UIDs can
   read/write a space + subcollections; `pairCodes` readable by anyone for redemption,
   writable only by their creator; join adds member #2 atomically with no takeover).
   Deploy via console paste or `firebase deploy --only firestore:rules`.
7. **Cloud Messaging (FCM) setup**: in Project Settings → Cloud Messaging, upload the
   **APNs Authentication Key** (`.p8`) with its Key ID + Team ID from the Apple
   Developer account. Required for FCM token minting even on Spark.
8. **Xcode capabilities** on the app target: **Push Notifications**, and **Background
   Modes → Remote notifications** (the latter already exists for CloudKit silent
   push — keep it). Remove the **iCloud / CloudKit** capability and the
   `iCloud.me.adithyan.shalinth.Tweli` container after cutover verification (R6).
9. **(Optional, for the universal invite link)** enable **Firebase Hosting** (free on
   Spark), deploy a tiny static `/join` page + `apple-app-site-association` so
   `https://<project-id>.web.app/join?code=…` opens the app. Skip for a code-only MVP
   (see Assumptions).
10. **`FirebaseApp.configure()`** must be called once at launch — add to
    `AppDelegate.application(_:didFinishLaunchingWithOptions:)` before
    `registerForRemoteNotifications()`.

---

## Caller migration impact (for the UI / tasks planner)

Most call sites are unaffected (same method names). The exceptions:

- **`PendingInvite`** (`Tweli/Models/PendingInvite.swift`) currently wraps
  `CKShare.Metadata`. Rewrite it to wrap `PairInvite` (or hold `spaceId`,
  `spaceTitle`, `inviterName` directly). `spaceTitle` and `inviterName` map straight
  across; drop the CloudKit title-parsing.
- **`AppViewModel`**: remove `import CloudKit`; `handleAcceptedShare(_ metadata:)`
  and `confirmPendingJoin()` switch from `acceptShare` to `joinSpace(_:participantName:)`;
  `joinWithCode` builds `PendingInvite` from `PairInvite`. `syncNow()` becomes
  "start listeners once." `AppDelegate.onAcceptShare` /
  `userDidAcceptCloudKitShareWith` are deleted (no CKShare accept callback);
  universal-link/`tweli://` handling in `handleDeepLink` stays.
- **`CreateSpaceView`**: remove `import CloudKit`; drop the `accountStatus()`
  preflight and `CKError.quotaExceeded` branch (the bug being fixed); `createShare`
  → `createSpace`; build `inviteLink` from the code, not `share.url`. The pair-code
  card and share-message composition are unchanged.
- **`JoinSpaceView`**: `CloudKitService.normalizePairCode` →
  `FirebaseService.normalizePairCode`; the pasted-`https`-link branch now extracts
  `?code=` from our Hosting link and redeems directly instead of
  `UIApplication.shared.open(url)`.
- **`AppDelegate`**: keep `didReceiveRemoteNotification` (future Blaze push), drop the
  CloudKit share-accept method, add FCM `MessagingDelegate` token handling.

---

## Assumptions (auto-mode defaults; no AskUserQuestion)

- **[Auth session storage]** Rely on Firebase Auth's built-in Keychain session
  persistence as the canonical signed-in state; `init()` reads
  `Auth.auth().currentUser`. This also resolves the existing AuthService TODO
  ("move user id to Keychain"). UserDefaults keeps only the display name for
  offline/first-paint. Reason: standard Firebase pattern; no conflicting signal.
- **[DEBUG bypass = offline, no network]** `devSignIn()` stays fully offline with a
  synthetic `dev-` uid; `FirebaseService` short-circuits all network on that uid.
  Provided `devSignInWithRealSync()` (anonymous auth) as an opt-in only. Reason: R1
  explicitly says the bypass must make no network call.
- **[Invite link transport]** Recommend Firebase Hosting universal link
  (`https://<project>.web.app/join?code=…`) as primary because messaging apps only
  linkify https; `tweli://join?code=…` + the visible 6-char code are the fallback. If
  Hosting is deferred, ship **code-only** (the human types/pastes the code) — the
  redeem path is identical, only the tappable-link affordance is lost. Both are free
  on Spark. Chosen because it preserves today's "tap to join" UX at zero cost.
- **[RType values → plural collection names]** Changed the `RType` string constants to
  Firestore collection names (`"reminders"`, …). Safe because callers reference them
  symbolically. Must match database.md's collection paths — coordinating value is the
  plural lowercase form.
- **[Full-space case]** Added an explicit "space is full" outcome to `joinSpace`
  (surfaced via `badShareURL` copy or a new friendly string) because Firestore, unlike
  CKShare, has no built-in participant cap UX. Flagged to the UI planner. Reason: max-2
  membership (R2/R3) needs a user-visible failure when a third person tries to join.
- **[Push on Spark]** MVP delivers pings via live listeners + stores FCM tokens;
  true background cross-device push is deferred to a Blaze Cloud Function. Reason: R5
  permits deferring server push; Cloud Functions require Blaze and client-to-client
  FCM is insecure.
- **[Server timestamps]** Use `FieldValue.serverTimestamp()` for `createdAt`/
  `updatedAt`/`expiresAt` write-time on the client via `Date().addingTimeInterval` for
  `expiresAt` (48h) to keep redemption comparison simple and offline-tolerant, matching
  today's client-computed expiry. Reason: parity with current 48h client-side expiry.
</content>
</invoke>
