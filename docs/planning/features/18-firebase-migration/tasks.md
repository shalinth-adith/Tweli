<!-- IMMUTABLE: DO NOT modify task descriptions below. Only update checkboxes. Status tracking is in feature-status.json. -->

# Tasks — 18 Firebase Migration (CloudKit → Firebase)

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Platform**: SwiftUI, iOS-only. Xcode project `Tweli.xcodeproj`, sources under `Tweli/`, widget under `TweliWidget/`.
**Backend**: Firebase — Firestore + Firebase Auth + FCM, Spark (free) plan.
**Generated**: 2026-07-11 by @task-generator

## Overview

This is a **cutover, not a dual-run**: `CloudKitService` is replaced by a new
`FirebaseService` at the single backend boundary, preserving the same Swift method
names, static helpers, and nested types so most call sites are untouched. There is no
web backend, no REST API, and no database migration files — the "backend" is the Swift
service layer wrapping the Firebase iOS SDK (SPM). There is no CloudKit production data
to migrate (pre-launch), so CloudKit and its entitlements are retired once verification
passes.

The plan is sequenced as thin vertical slices, each independently verifiable, following
the FEATURE_INDEX.md implementation sequence:

1. **Phase 0 — Console setup (user-owned)**: Firebase console + Xcode capability steps
   that block build/runtime and cannot be scripted from the app.
2. **Phase 1 — SPM + config**: add the Firebase SDK, `FirebaseApp.configure()`.
3. **Phase 2 — FirebaseService skeleton**: role/spaceId persistence, Firestore
   persistence settings, DEBUG offline bypass.
4. **Phase 3 — Auth**: Sign in with Apple → Firebase Auth (nonce flow).
5. **Phase 4 — Invite flow**: space create + pair-code publish/redeem/atomic join +
   `PendingInvite` reshape.
6. **Phase 5 — Item sync**: item CRUD wrappers + snapshot listeners + `AppViewModel`
   rewiring.
7. **Phase 6 — Push**: FCM token registration (background push deferred to Blaze).
8. **Phase 7 — UI rewiring**: state/copy/plumbing in the four affected views +
   accessibility identifiers.
9. **Phase 8 — Widget check**: confirm local-only handoff, no Firebase in the widget.
10. **Phase 9 — Cleanup**: retire `CloudKitService`, remove iCloud/CloudKit capability
    + container.
11. **Phase 10 — Verification**: build, two-simulator invite flow, deletion
    propagation, no CloudKit imports remain.

**Key cross-cutting invariants** (from the specs — every task must respect these):
- **Dual identity**: Firebase UID (`String`) is membership/rule identity; App profile id
  (`UserProfile.id: UUID`) stays inside item JSON payloads. The Firebase UID never enters
  a payload.
- **Thin payload**: every item document is `{ payload: <JSON string>, authorUid, updatedAt:
  serverTimestamp, schemaVersion: 1 }`; doc ID = `item.id.uuidString`.
- **`RType` collection strings are plural lowercase**: `reminders`, `countdowns`,
  `letters`, `virtualDates`, `moods`, `pings` — must match Firestore paths.
- **Max-2 join** enforced twice: Firestore transaction (friendly path) + security rules
  (real guard).
- **Background push deferred** — Spark/Blaze boundary; MVP = foreground listeners + local
  notifications + FCM token storage.

## Specifications analyzed

- `requirements.md` — R1–R7 contract
- `database.md` — Firestore schema, security rules, indexes, offline, quota
- `api-endpoints.md` — `FirebaseService` Swift surface, auth flow, invite flow, sync,
  FCM, SPM, prerequisites, caller migration impact
- `ui-components.md` — state/copy/plumbing changes for the four affected views, a11y ids
- `FEATURE_INDEX.md` — reading order + suggested implementation sequence

---

## Phase 0 — Console & Xcode setup (USER-OWNED — blocks build/runtime)

> These require the Firebase Console / Apple Developer account / Xcode capability editor
> and **cannot be scripted from the app**. They are the load-bearing prerequisites: the
> app will not authenticate or reach Firestore without them. Present as a checklist to
> the user. Source: database.md §9, api-endpoints.md "User-facing prerequisites",
> FEATURE_INDEX.md "Console prerequisites".

### SETUP-1: Create Firebase project + register iOS app (USER — Firebase console)
Create/confirm a Firebase project for Tweli, kept on the **Spark (free)** plan. Register
an iOS app with bundle id **`me.adithyan.shalinth.Tweli`**. The `TweliWidget` extension
is **not** registered (it is not a Firebase client — R7).
- **Acceptance**: An iOS app with bundle id `me.adithyan.shalinth.Tweli` exists in the
  Firebase project on the Spark plan; a `GoogleService-Info.plist` is downloadable.
- **Owner**: User (console). Blocks: all runtime tasks.

### SETUP-2: Add GoogleService-Info.plist to the app target (USER — Xcode)
Download `GoogleService-Info.plist` and add it to the **app target only** (Build Phases →
Copy Bundle Resources), not the widget target. Add it to `.gitignore` and note where
teammates obtain it.
- **Files**: `GoogleService-Info.plist` (app target), `.gitignore`.
- **Acceptance**: The plist is in the app bundle resources; a debug build finds it at
  runtime (no "GoogleService-Info.plist not found" console warning). It is git-ignored.
- **Owner**: User (Xcode). Depends on: SETUP-1.

### SETUP-3: Enable Apple sign-in provider (USER — Firebase console)
In **Authentication → Sign-in method**, enable the **Apple** provider. The native nonce
flow needs nothing further (no Services ID / key / redirect) as long as the bundle id
matches (R1).
- **Acceptance**: Apple provider shows "Enabled" in the Firebase Auth console.
- **Owner**: User (console). Depends on: SETUP-1.

### SETUP-4: Create the Firestore database (USER — Firebase console)
Create **Firestore Database** in Native/production mode; pick a region (permanent choice).
- **Acceptance**: A Firestore database exists in Native mode with a chosen region.
- **Owner**: User (console). Depends on: SETUP-1.

### SETUP-5: Author + deploy Firestore security rules and empty indexes (USER + dev)
Add `firestore.rules` (verbatim from database.md §3) and `firestore.indexes.json` (the
empty `{ "indexes": [], "fieldOverrides": [] }` from §4) to the repo, then deploy via
`firebase deploy --only firestore:rules,firestore:indexes` or console paste. Rules must
enforce: member-only space read/write, world-readable / creator-writable pair codes, and
the `isAtomicJoin` / `isMemberEdit` guards (max-2, no takeover).
- **Files**: `firestore.rules`, `firestore.indexes.json` (repo root or `firebase/`).
- **Acceptance**: Rules deployed and visible in the console; the `isAtomicJoin` and
  `isMemberEdit` functions match database.md §3 exactly.
- **Owner**: User deploys; dev authors the files. Depends on: SETUP-4.

### SETUP-6: Upload APNs auth key for FCM (USER — Firebase console + Apple Developer)
In **Project Settings → Cloud Messaging**, upload the **APNs Authentication Key** (`.p8`)
with its Key ID + Team ID. Required for FCM token minting even on Spark.
- **Acceptance**: The APNs key is listed under Cloud Messaging → Apple app configuration.
- **Owner**: User (console). Depends on: SETUP-1.

### SETUP-7: Xcode capabilities — add Push, keep Background Modes (USER — Xcode)
On the **app target**, add **Push Notifications** and confirm **Background Modes → Remote
notifications** (the latter already exists for CloudKit silent push — keep it for now;
the iCloud/CloudKit capability is removed later in CLEAN-2).
- **Files**: app target capabilities / `Tweli/Tweli.entitlements`.
- **Acceptance**: Push Notifications + Background Modes (Remote notifications) are enabled
  on the app target; the build still signs.
- **Owner**: User (Xcode). Depends on: SETUP-1.

### SETUP-8: (Optional) Firebase Hosting universal link (USER — deferrable)
Optionally enable **Firebase Hosting** (free on Spark) and deploy a tiny `/join` page +
`apple-app-site-association` so `https://<project>.web.app/join?code=…` opens the app.
**Skip for a code-only MVP** — the redeem path is identical; only the tappable-https-link
affordance is lost (the `tweli://join?code=…` fallback and the visible 6-char code still
work).
- **Acceptance**: Either Hosting `/join` resolves into the app, OR this task is explicitly
  deferred and the code-only invite path is confirmed working in INV-2 / UI-2.
- **Owner**: User (console). Optional; depends on: SETUP-1.

---

## Phase 1 — SPM dependency + Firebase bootstrap

### SPM-1: Add firebase-ios-sdk and link products to the app target only
Add `https://github.com/firebase/firebase-ios-sdk` via SPM, pinned
`.upToNextMajor(from: "11.0.0")`. Link **only** `FirebaseCore`, `FirebaseAuth`,
`FirebaseFirestore`, `FirebaseMessaging` to the **app target**. Do **not** add
`FirebaseFirestoreSwift` (absorbed into `FirebaseFirestore` in v11). Link **none** of them
to the `TweliWidget` target (R7).
- **Files**: `Tweli.xcodeproj/project.pbxproj` (package refs + app target frameworks).
- **Acceptance**: `import FirebaseCore` / `FirebaseAuth` / `FirebaseFirestore` /
  `FirebaseMessaging` compile in an app-target file; the widget target links no Firebase
  product; the app target builds clean.
- **Depends on**: none (code-only; can precede console tasks). Blocks: SPM-2, FS-1.

### SPM-2: Call FirebaseApp.configure() at launch
In `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, call
`FirebaseApp.configure()` **once**, before `registerForRemoteNotifications()`.
- **Files**: `Tweli/App/AppDelegate.swift`.
- **Acceptance**: On launch (with `GoogleService-Info.plist` present) Firebase initializes
  with no console error; ordering is before push registration.
- **Depends on**: SPM-1, SETUP-2.

---

## Phase 2 — FirebaseService skeleton

### FS-1: Create FirebaseService with config, role/spaceId persistence, and Firestore settings
Create `@MainActor final class FirebaseService: ObservableObject` mirroring
`CloudKitService`'s surface. Include the nested `Role` enum (`none/owner/participant`) and
`RType` with the **plural lowercase** collection constants (`reminders`, `countdowns`,
`letters`, `virtualDates`, `moods`, `pings`); `@Published private(set) var role`;
`@Published private(set) var accountAvailable`; `var currentUid: String?`;
`private(set) var spaceId: String?` (cached in UserDefaults). `init()` reads persisted
role + spaceId and configures Firestore persistence via
`FirestoreSettings.cacheSettings = PersistentCacheSettings()`. Provide
`refreshAccountStatus()` reflecting Firebase Auth state (never `CKError`).
- **Files**: `Tweli/Services/FirebaseService.swift` (new).
- **Acceptance**: The class compiles; `RType` strings are exactly the six plural lowercase
  names matching database.md paths; role + spaceId survive an app relaunch; Firestore
  persistent cache is set explicitly in `init()`.
- **Depends on**: SPM-1.

### FS-2: DEBUG offline bypass (devSignIn + dev- short-circuit)
Add `#if DEBUG func devSignIn()` that sets a synthetic `dev-<uuid>` uid and
`accountAvailable = true` with **no network call**. Gate every Firestore read/write/listener
in `FirebaseService` on `currentUid != nil && currentUid?.hasPrefix("dev-") == false` so
debug builds run entirely on `MockData` + local stores. Compile-time excluded from release.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: A DEBUG build calling `devSignIn()` makes zero network calls; all
  service network methods early-return under a `dev-` uid; the code is inside `#if DEBUG`.
- **Depends on**: FS-1.

---

## Phase 3 — Sign in with Apple → Firebase Auth (R1)

### AUTH-1: Nonce generation in AuthService.configure
In `AuthService`, generate a cryptographically random `rawNonce` (32 bytes via
`SecRandomCopyBytes`), stash it, and set `request.nonce = sha256(rawNonce)` in
`configure(request:)` alongside the existing `requestedScopes = [.fullName, .email]`. No
new login screens; same `SignInWithAppleButton` UX.
- **Files**: `Tweli/Services/AuthService.swift`.
- **Acceptance**: The authorization request carries a SHA-256 nonce; the raw nonce is
  retained for the credential exchange; existing scopes unchanged.
- **Depends on**: SPM-1.

### AUTH-2: signInWithApple credential exchange in FirebaseService
Add `func signInWithApple(idToken:rawNonce:fullName:) async throws -> FirebaseUser`
building `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` and calling
`Auth.auth().signIn(with:)`. Return `FirebaseUser { uid; displayName }` (display name from
Apple `fullName` on first auth, else persisted name, else `"You"`). `AuthService` calls
this from the `SignInWithAppleButton` completion and persists uid + display name exactly as
`store(userId:name:)` does today. The Firebase UID is canonical; the local `UserProfile`
UUID is untouched.
- **Files**: `Tweli/Services/FirebaseService.swift`, `Tweli/Services/AuthService.swift`.
- **Acceptance**: A real Apple sign-in returns a Firebase UID and sets
  `accountAvailable = true`; display name persists; no `UserProfile.id` change.
- **Depends on**: AUTH-1, FS-1, SETUP-3 (runtime).

### AUTH-3: signOut + session restore on cold launch
Add `func signOut() throws` (Firebase Auth sign-out; clears role + spaceId) and make
`init()` / `refreshAccountStatus()` read `Auth.auth().currentUser` so a persisted Keychain
session restores `accountAvailable` on cold launch (resolves the AuthService
"move user id off UserDefaults" TODO). UserDefaults keeps only the display name for
first-paint.
- **Files**: `Tweli/Services/FirebaseService.swift`, `Tweli/Services/AuthService.swift`.
- **Acceptance**: Relaunching a signed-in build lands authenticated without re-prompting
  Apple; `signOut()` returns to the unauthenticated state and clears role/spaceId.
- **Depends on**: AUTH-2.

---

## Phase 4 — Space creation + pair-code invite flow (R3)

### INV-1: createSpace(title:)
Add `func createSpace(title: String) async throws -> String` writing `spaces/{spaceId}`
(auto-id) with `title`, `ownerUid = currentUid`, `memberUids = [ownerUid]`,
`memberNames = { ownerUid: displayName }`, `createdAt`/`updatedAt = serverTimestamp()`.
Sets `role = .owner`, caches `spaceId`, returns the id. Replaces `createShare()`; no URL
minting wait. Keep `createCoupleSpace(_:)` as a no-op for call-site compatibility.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: Calling `createSpace` creates one `spaces/{spaceId}` doc satisfying the
  `create` rule (owner is sole member); `role == .owner`; `spaceId` cached and returned.
- **Depends on**: AUTH-2, SETUP-5 (rules), FS-1.

### INV-2: publishPairCode + static normalize/alphabet + shareable link
Add `func publishPairCode(spaceTitle:) async throws -> String`: reuse a cached unexpired
code (`tweli.pairCode` UserDefaults) if its `pairCodes/{cached}` doc still exists and
`expiresAt > now`, else generate a 6-char code from the **identical** alphabet
`23456789ABCDEFGHJKMNPQRSTUVWXYZ` and write `pairCodes/{code}` with `spaceId`, `spaceTitle`,
`createdBy = ownerUid`, `createdByName = displayName`, `expiresAt = now + 48h`,
`createdAt = serverTimestamp()`. Keep `static func normalizePairCode(_:) -> String` and
`static let codeAlphabet` identical to today. Build the shareable link client-side by
encoding the code (`https://<project>.web.app/join?code=CODE` primary,
`tweli://join?code=CODE` always-present fallback).
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: Publishing writes a `pairCodes/{code}` doc keyed by the normalized code;
  re-publishing within 48h returns the same code; alphabet excludes 0/O/1/I/L; the invite
  link carries the code as a `?code=` query param.
- **Depends on**: INV-1.

### INV-3: redeemPairCode → PairInvite + PairCodeError taxonomy
Add `struct PairInvite: Identifiable { spaceId; spaceTitle; inviterName }` and
`func redeemPairCode(_ raw:) async throws -> PairInvite`: normalize →
`getDocument(pairCodes/{code})`; missing doc → `.notFound`; other read failure →
`.network` (never `.notFound`); `expiresAt < now` → `.expired`; missing/blank `spaceId` →
`.badShareURL`; else return `PairInvite(spaceId, spaceTitle, inviterName: createdByName ??
"Your partner")`. Define `enum PairCodeError: LocalizedError { notFound, expired,
badShareURL, network }` with the **exact unchanged copy** from api-endpoints.md /
ui-components.md §5. Drop `shareURLNotReady`.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: Each error branch maps to the specified verbatim copy; a valid code
  returns a `PairInvite` with a non-empty `inviterName`; `shareURLNotReady` does not exist.
- **Depends on**: INV-2.

### INV-4: joinSpace atomic transaction (max-2, no-takeover, space-full)
Add `func joinSpace(_ invite: PairInvite, participantName: String) async throws` running a
Firestore transaction on `spaces/{spaceId}`: re-read; if `memberUids.count >= 2` and
`currentUid` not present → throw a friendly **"space is full"** error; else
`arrayUnion(currentUid)` into `memberUids`, set `memberNames[currentUid] = participantName`.
On success set `role = .participant`, cache `spaceId`, start listeners. Security rules
(SETUP-5) independently enforce max-2 / no-takeover.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: A second user joins a solo space and becomes member #2; a third join
  attempt (or a race) throws the space-full error and does not mutate `memberUids`; the
  transaction passes `isAtomicJoin`.
- **Depends on**: INV-3, SETUP-5.

### INV-5: Reshape PendingInvite to a plain struct
Rewrite `PendingInvite` to wrap `PairInvite` (or hold `spaceId`, `spaceTitle`,
`inviterName` directly) instead of `CKShare.Metadata`. Preserve the load-bearing non-empty
fallbacks used by `JoinConfirmView` (`"your shared space"` / `"Your partner"`). Drop
`import CloudKit` and all share-title / `PersonNameComponents` parsing.
- **Files**: `Tweli/Models/PendingInvite.swift`.
- **Acceptance**: `PendingInvite` no longer imports CloudKit; `spaceTitle` / `inviterName`
  keep their names and fallback behavior; the type constructs cleanly from a `PairInvite`.
- **Depends on**: INV-3.

---

## Phase 5 — Item sync: CRUD wrappers + snapshot listeners

### SYNC-1: Item CRUD wrappers writing the thin payload document
Implement the generic `save<T: Codable>(_:id:type:)` / `delete(id:type:)` writing/removing
`spaces/{spaceId}/{type}/{item.id.uuidString}` with `{ payload: <JSON string>, authorUid:
currentUid, updatedAt: serverTimestamp(), schemaVersion: 1 }`, and the typed wrappers with
**unchanged signatures**: `saveReminder/deleteReminder`, `saveCountdown/deleteCountdown`,
`saveLetter`, `saveVirtualDate`, `saveMood`, `sendPing`. All are no-ops when `role == .none`
or `spaceId == nil` (matching today's guard) and under a `dev-` uid.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: Saving any item type produces a doc keyed by `id.uuidString` with the four
  fields; `payload` decodes back to the original model; `authorUid == currentUid`; delete
  removes the doc; feature-service call sites compile unchanged.
- **Depends on**: INV-1, FS-2.

### SYNC-2: Snapshot listeners + RemoteChanges + space-doc listener
Add `func startListening(onChange: @escaping (RemoteChanges) -> Void)` /
`func stopListening()`. Attach one listener per item subcollection (6) plus one on
`spaces/{spaceId}` (7 total). For item snapshots, iterate `documentChanges`:
`.added`/`.modified` → append payload `Data` into `RemoteChanges.payloadsByType[RType]`;
`.removed` → `UUID(uuidString: documentID)` into `deletedIDs`. For the space doc, set
`RemoteChanges.partnerJoinedName` when `memberUids.count == 2`. Use
`includeMetadataChanges = false`. `RemoteChanges` keeps the **same shape**
(`payloadsByType`, `deletedIDs`, `partnerJoinedName`) that `AppViewModel` already merges.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: With listeners attached, a remote add/modify delivers a payload and a
  remote delete delivers a `deletedID` through the callback; the space-doc listener reports
  the partner's name on join; `stopListening()` detaches all seven.
- **Depends on**: SYNC-1.

### SYNC-3: fetchChanges() back-compat shim
Add `func fetchChanges() async -> RemoteChanges` that does a one-shot `getDocuments` per
subcollection (for pull-to-refresh / first sync), listener-independent, returning the same
`RemoteChanges` shape.
- **Files**: `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: Calling `fetchChanges()` returns the current item set as `RemoteChanges`
  without attaching listeners; a `dev-` uid returns empty without network.
- **Depends on**: SYNC-2.

### SYNC-4: Rewire AppViewModel to FirebaseService (syncNow shrink, join, deletions)
In `AppViewModel`: remove `import CloudKit`; swap the `CloudKitService` dependency for
`FirebaseService`; `syncNow()` shrinks to "start listeners once + `refreshWidget()` on each
callback"; `handleAcceptedShare` / `confirmPendingJoin` switch to
`joinSpace(_:participantName:)`; `joinWithCode` builds `PendingInvite` from `PairInvite`;
universal-link / `tweli://` handling in `handleDeepLink` stays. The existing `decode(_:)` +
`mergeRemote(_:deletedIDs:)` wiring consumes `RemoteChanges` unchanged.
- **Files**: `Tweli/App/AppViewModel.swift`.
- **Acceptance**: `AppViewModel` has no `import CloudKit`; live sync flows through listeners;
  a remote deletion removes the item locally via `mergeRemote`; join goes through
  `joinSpace`; the app builds.
- **Depends on**: SYNC-2, INV-4, INV-5.

---

## Phase 6 — FCM push (token storage only; background push deferred to Blaze — R5)

### PUSH-1: FCM token registration + MessagingDelegate wiring
Add `func registerForPush() async` (obtain + store the FCM token; **no** server
subscription on Spark) and `func updateFCMToken(_ token:) async` writing the token onto the
member entry (e.g. `spaces/{spaceId}` field `fcmTokens[uid]`). In `AppDelegate`, add
`MessagingDelegate`; on `messaging(_:didReceiveRegistrationToken:)` call `updateFCMToken`.
**Keep** `didReceiveRemoteNotification` wired (future Blaze push) and **drop** the CloudKit
share-accept method. Do **not** attempt client-to-client FCM sends. Background cross-device
push is a documented Blaze follow-up.
- **Files**: `Tweli/App/AppDelegate.swift`, `Tweli/Services/FirebaseService.swift`.
- **Acceptance**: On a signed-in device the FCM token is stored on the space doc; the
  `MessagingDelegate` callback fires; `didReceiveRemoteNotification` still routes to
  `syncNow()`; no service-account credential ships in the app.
- **Depends on**: SYNC-4, SETUP-6 (runtime).

---

## Phase 7 — UI rewiring (no visual redesign — states/copy/plumbing only)

### UI-1: CreateSpaceView — collapse invite creation, drop iCloud preflight
Remove `import CloudKit`; delete the `accountStatus()` iCloud pre-flight and the
`CKError.quotaExceeded` / `noAccount` / `restricted` / `couldNotDetermine` /
`temporarilyUnavailable` branches; `createShare` → `createSpace`; build `inviteLink` from
the pair code (not `share.url`). Keep the `preparingShare` "Creating link…" spinner (now one
Firestore write). Error surface shrinks to network + generic-write copy (ui-components.md
§5). Pair-code card, `shareMessage`, `ShareLink`, copy-to-clipboard flash unchanged.
- **Files**: `Tweli/Views/Room/CreateSpaceView.swift`.
- **Acceptance**: No `import CloudKit`; no iCloud/quota branches remain; tapping create
  yields `inviteLink` + `pairCode` together; the two retired error copies do not appear;
  layout pixel-identical.
- **Depends on**: INV-1, INV-2.

### UI-2: JoinSpaceView — unify all three input shapes onto one redeem path
Point `normalizePairCode` at `FirebaseService`. Re-derive `pastedURL` handling to **extract
the `code` query param** from any pasted `https://` URL and route through the same
`codeToRedeem` → `app.joinWithCode(code)` path as a typed code or `tweli://` link (no more
`UIApplication.shared.open` / OS share-accept). `matchedPreview` copy stays (describes input
shape). `header`, `codeField`, `errorCard`, button state machine unchanged.
- **Files**: `Tweli/Views/Room/JoinSpaceView.swift`.
- **Acceptance**: Typed code, `tweli://join?code=`, and `https://…?code=` all redeem via one
  path; `isValid` / `app.joinError` / `app.redeemingCode` remain the only three UI signals;
  layout unchanged.
- **Depends on**: INV-3, SYNC-4.

### UI-3: JoinConfirmView — reshaped PendingInvite + space-full copy
Read `invite.spaceTitle` / `invite.inviterName` off the reshaped `PendingInvite` exactly as
today (fallbacks preserved). Split the join error path: keep the generic "Couldn't join
right now…" copy for transaction failures, and add the **new space-full copy** — "This space
already has two people. Ask your partner to send you a fresh invite." — for the atomic
max-2 failure from INV-4. Layout / `joining` / `joinFailed` state machine unchanged.
- **Files**: `Tweli/Views/Room/JoinConfirmView.swift`.
- **Acceptance**: Confirm sheet renders title/inviter from the plain struct; a full-space
  join shows the new copy while other failures show the generic copy; layout unchanged.
- **Depends on**: INV-4, INV-5.

### UI-4: SettingsView — real sync status + leave/sign-out under Firebase
Replace the CloudKit `row("icloud.fill", "iCloud sync", "On (mock)", …)` with a real
3-state **Sync** row: "Connected" (space + active listener), "Offline" (serving Firestore
cache), "Not connected" (no space). `disconnect()` removes `currentUid` from `memberUids`
(or deletes the space if sole member) instead of tearing down CloudKit zones; no new
confirmation step (MVP parity). `Sign out` calls `disconnect()` then `auth.signOut()` (now
also tears down the Firebase Auth session). Other rows unchanged.
- **Files**: `Tweli/Views/Settings/SettingsView.swift`.
- **Acceptance**: The sync row shows a real state string (never "iCloud"/"On (mock)");
  leave removes membership; sign-out ends the Firebase session; other sections untouched.
- **Depends on**: SYNC-4, AUTH-3.

### UI-5: Add accessibility identifiers for verification
Add `tweli.<view>.<element>` accessibility identifiers to the invite-flow controls per
ui-components.md §7 (`tweli.createSpace.nameField`, `.createInviteButton`, `.skipButton`,
`.continueButton`, `.inviteLinkText`, `.pairCodeText`, `.errorLabel`;
`tweli.joinSpace.codeField`, `.joinButton`, `.errorLabel`, `.matchedPreview`;
`tweli.joinConfirm.joinButton`, `.notNowButton`, `.errorLabel`;
`tweli.settings.syncStatusRow`, `.leaveSpaceButton`, `.signOutButton`).
- **Files**: `Tweli/Views/Room/CreateSpaceView.swift`,
  `Tweli/Views/Room/JoinSpaceView.swift`, `Tweli/Views/Room/JoinConfirmView.swift`,
  `Tweli/Views/Settings/SettingsView.swift`.
- **Acceptance**: Each listed identifier is present and resolvable via
  `snapshot_ui` / accessibility inspection; no visual change.
- **Depends on**: UI-1, UI-2, UI-3, UI-4.

---

## Phase 8 — Widget verification (R7 — local-only, no Firebase)

### WIDGET-1: Confirm the widget stays local-only with no Firebase dependency
Verify `TweliWidget` reads shared data via the App Group (`WidgetDataService` +
`WidgetSnapshot`) with **no** CloudKit or Firebase dependency, and that `WidgetDataService`
(app side) still writes the snapshot on each sync callback (`refreshWidget()` in SYNC-4).
The widget target links zero Firebase products (SPM-1).
- **Files**: `TweliWidget/` (all), `Tweli/Services/WidgetDataService.swift`.
- **Acceptance**: The widget target imports no CloudKit/Firebase; widgets
  (`CountdownWidget`, `NextDateWidget`, `PartnerMoodWidget`, `LastPingWidget`) render from
  the App Group snapshot after an app-side sync; widget builds independently.
- **Depends on**: SYNC-4, SPM-1.

---

## Phase 9 — Cutover cleanup (R6 — retire CloudKit)

### CLEAN-1: Retire CloudKitService
Delete `Tweli/Services/CloudKitService.swift` and remove its target membership from the
project. Confirm no source references `CloudKitService` outside comments/history.
- **Files**: `Tweli/Services/CloudKitService.swift` (deleted),
  `Tweli.xcodeproj/project.pbxproj`.
- **Acceptance**: The file is gone; `grep -rn "CloudKitService" Tweli/` returns nothing; the
  app builds.
- **Depends on**: SYNC-4, UI-1, UI-2, UI-3, UI-4, PUSH-1.

### CLEAN-2: Remove iCloud/CloudKit capability + container from app entitlements
Remove the **iCloud / CloudKit** capability and the `iCloud.me.adithyan.shalinth.Tweli`
container from `Tweli/Tweli.entitlements` and the app target capabilities. Keep the App
Group (widget handoff) and Push Notifications / Background Modes (Remote notifications).
- **Files**: `Tweli/Tweli.entitlements`, `Tweli.xcodeproj/project.pbxproj`.
- **Acceptance**: `grep -rn "iCloud.me.adithyan" Tweli/` returns nothing; the App Group and
  push entitlements remain; the app signs and builds.
- **Depends on**: CLEAN-1.

### CLEAN-3: Confirm no CloudKit imports or symbols remain anywhere
Sweep the whole project (app + widget) for residual CloudKit usage after the reshapes in
INV-5, SYNC-4, UI-1, PUSH-1, CLEAN-1/2.
- **Files**: all under `Tweli/` and `TweliWidget/`.
- **Acceptance**: `grep -rn "import CloudKit\|CKShare\|CKRecord\|CKError\|userDidAcceptCloudKitShareWith" Tweli/ TweliWidget/`
  returns zero results; the app + widget targets build.
- **Depends on**: CLEAN-1, CLEAN-2, INV-5, SYNC-4, UI-1, PUSH-1.

---

## Phase 10 — Verification

### TEST-1: Build passes for app + widget targets
Build both the app and widget targets clean (`xcodebuild -scheme <scheme> -destination
'platform=iOS Simulator,name=iPhone 16' build`, exit 0).
- **Acceptance**: Both targets compile and link with zero errors; no Firebase in the widget
  target.
- **Depends on**: CLEAN-3.

### TEST-2: DEBUG auth bypass lands authenticated (single simulator)
Run a Debug build; confirm the `#if DEBUG` `devSignIn()` bypass lands directly on the
authenticated/main screen with no network and no login prompt. Capture a screenshot to
`docs/planning/features/18-firebase-migration/verification-screenshots/18-firebase-migration-auth-bypass.png`.
- **Acceptance**: Debug build reaches the main view offline; screenshot captured and
  referenced.
- **Depends on**: TEST-1, FS-2.

### TEST-3: Invite flow end-to-end across two simulators (real Firebase)
On two simulators signed in as two distinct Apple/Firebase users (or one Apple + one
anonymous via the documented `devSignInWithRealSync` opt-in): device A creates a space +
invite; device B redeems the code and joins; A sees B's name (space-doc listener); an item
saved on A appears on B via the listener. Also verify the **space-full** path: a third join
attempt shows the new full-space copy. Capture screenshots (`…-create.png`, `…-join.png`,
`…-synced.png`, `…-space-full.png`).
- **Acceptance**: Create → join → live item sync works both directions; partner name
  surfaces on join; a third join is rejected with the space-full copy; screenshots captured.
- **Depends on**: TEST-1, INV-4, SYNC-4, UI-1, UI-2, UI-3, SETUP-1..5.

### TEST-4: Deletion propagation verified
Delete an item on device A; confirm it disappears on device B via the `.removed` snapshot
change (`deletedIDs` → `mergeRemote`). Confirm an offline-queued delete replays on reconnect.
- **Acceptance**: Remote deletion removes the item on the partner device; offline delete
  replays after reconnect.
- **Depends on**: TEST-3.

### TEST-5: No CloudKit references remain (grep gate)
Run the sweep from CLEAN-3 across `Tweli/` and `TweliWidget/` and confirm zero results, and
`grep -rn "iCloud.me.adithyan" .` (excluding docs/planning) is empty.
- **Acceptance**: No `import CloudKit`, `CKShare`, `CKRecord`, `CKError`,
  `userDidAcceptCloudKitShareWith`, or CloudKit container references remain in source.
- **Depends on**: CLEAN-3.

### TEST-6: Widget renders from the App Group snapshot
Add the widget to the home screen (or via widget preview) and confirm each widget populates
from the App Group snapshot after an app-side sync — no blank/failed renders, no Firebase in
the widget process.
- **Acceptance**: `CountdownWidget`, `NextDateWidget`, `PartnerMoodWidget`, `LastPingWidget`
  render real snapshot data; screenshot captured.
- **Depends on**: WIDGET-1, TEST-3.

---

## Summary

| Phase | Tasks | IDs |
|---|---|---|
| 0 — Console & Xcode setup (user) | 8 | SETUP-1 … SETUP-8 |
| 1 — SPM + bootstrap | 2 | SPM-1, SPM-2 |
| 2 — FirebaseService skeleton | 2 | FS-1, FS-2 |
| 3 — Auth (Sign in with Apple) | 3 | AUTH-1 … AUTH-3 |
| 4 — Invite flow | 5 | INV-1 … INV-5 |
| 5 — Item sync | 4 | SYNC-1 … SYNC-4 |
| 6 — FCM push (token only) | 1 | PUSH-1 |
| 7 — UI rewiring | 5 | UI-1 … UI-5 |
| 8 — Widget check | 1 | WIDGET-1 |
| 9 — Cutover cleanup | 3 | CLEAN-1 … CLEAN-3 |
| 10 — Verification | 6 | TEST-1 … TEST-6 |
| **Total** | **40** | |

**Critical path**: SETUP-1 → SPM-1 → FS-1 → AUTH-1/2 → INV-1 → INV-2 → INV-3 → INV-4 →
SYNC-1 → SYNC-2 → SYNC-4 → UI-1..4 → PUSH-1 → CLEAN-1 → CLEAN-2 → CLEAN-3 → TEST-1 →
TEST-3. Console tasks (SETUP-*) are user-owned and gate all runtime verification; code
tasks can be written before the console work finishes, but TEST-3/4/6 require the live
Firebase project.

**MVP acceptance**: the couple invite flow works end-to-end on two devices through
Firestore, live sync + deletions propagate via listeners, the DEBUG bypass still lands
authenticated offline, the widget still renders locally, and no CloudKit code or
entitlements remain. Background cross-device push (killed-app wake) is the one explicitly
deferred capability (Blaze Cloud Function follow-up).
