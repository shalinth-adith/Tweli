# Feature Index — 18 Firebase Migration (CloudKit → Firebase)

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Backend**: Firebase (Firestore + Firebase Auth + FCM), Spark (free) plan
**Platform**: SwiftUI, iOS. Bundle id `me.adithyan.shalinth.Tweli`
**Index generated**: 2026-07-11 by @feature-index-generator

Quick navigation: [Overview](#overview) · [Document inventory](#document-inventory) · [Quick stats](#quick-stats) · [Cross-cutting decisions](#key-cross-cutting-decisions) · [Reading order](#reading-order-for-implementers) · [Console prerequisites](#console-prerequisites-user-must-do-these-by-hand) · [Quick reference](#quick-reference)

---

## Overview

Tweli syncs a couple's shared space through CloudKit today
(`Tweli/Services/CloudKitService.swift`). CloudKit writes land in each **user's**
iCloud private database, so anyone sitting at 100% of their free 5 GB iCloud plan
gets `CKError.quotaExceeded` on the very first write (creating a space) — the app is
unusable for them, with no API to detect or prevent it. This was reproduced in real
testing on 2026-07-11 and is the whole reason for this feature.

This migration replaces the CloudKit sync layer with Firebase so storage counts
against the **project** quota instead of the user's iCloud. A user must never be
blocked by their personal storage again. It is a **cutover, not a dual-run**: there
is no production CloudKit data to migrate (the app is pre-launch), so `CloudKitService`
and the iCloud/CloudKit entitlements are retired once verification passes.

The single backend boundary — `CloudKitService`, called by every feature service
(`ReminderService`, `CountdownService`, `OpenWhenLetterService`, `VirtualDateService`,
`MoodService`, `MissingYouService`, `CoupleSpaceService`) — is replaced by a new
`FirebaseService` that preserves the same Swift method names, static helpers, and
nested types. Most call sites are untouched; the deliberate exceptions
(`PendingInvite`, the redeem return type, the new "space is full" join outcome) are
enumerated in the specs and summarized below.

**What is preserved:** couple space + owner/participant roles, the 6-char pair-code
invite flow with its exact alphabet/normalization/48h expiry, six Codable item types
synced as JSON payloads, offline behavior, and the "Send love" ping UX.

**What genuinely changes in capability:** true background/killed-app push (the
CloudKit silent zone-subscription equivalent) is **deferred** because it requires
Cloud Functions on the paid Blaze plan. MVP delivers live sync via foreground
snapshot listeners plus existing local notifications, and stores FCM tokens so a
later Blaze function is a pure add.

---

## Document inventory

Four planning specs. Read them in the order given under
[Reading order](#reading-order-for-implementers).

### `requirements.md` — the contract (≈6 KB)
The problem statement, migration goal, and the seven numbered requirements every
downstream spec is built against. Start here.

- **Problem / Goal / Current architecture** — why CloudKit fails and what
  `CloudKitService` currently does (the 5 capabilities to reproduce).
- **R1** — Firebase Auth via Sign in with Apple (nonce flow), keep the `#if DEBUG`
  bypass.
- **R2** — Firestore data model (spaces, item subcollections, pair codes, security
  rules).
- **R3** — invite-flow parity (create → code + link; redeem code or deep link → join).
- **R4** — sync parity via snapshot listeners; deletions must propagate; offline.
- **R5** — FCM push, with the explicit allowance to defer server push (Blaze) and
  rely on foreground listeners + local notifications for MVP.
- **R6** — cutover, not dual-run; retire CloudKit after verification.
- **R7** — widget (`TweliWidget` + `WidgetDataService`) must keep working, local-only.
- **Constraints / Out of scope** — Spark plan, SPM Firebase v11+, console steps must
  be documented; no data migration, no Android/web, no Blaze features required.

### `database.md` — Firestore schema + security rules (≈28 KB)
Authoritative schema, security rules, indexes, offline, and quota analysis. Written
for the developer building `FirebaseService`.

- **§1 Design Overview** — CloudKit→Firestore mapping table; ID strategy (`spaceId`,
  item doc IDs, pair-code-as-doc-ID).
- **§2 Collections & Document Schemas** — `spaces/{spaceId}` fields; the shared
  item-document shape (`payload` JSON string + `authorUid` + `updatedAt` +
  `schemaVersion`); per-type model reference; `pairCodes/{code}` fields; code
  generation & normalization.
- **§3 Security Rules** — complete `firestore.rules`: member-only space access,
  world-readable/creator-writable pair codes, and the `isAtomicJoin` /`isMemberEdit`
  update guards enforcing max-2 / no-takeover. Read the rule design notes.
- **§4 Composite Indexes** — none required for MVP; `firestore.indexes.json` ships
  empty.
- **§5 Offline Persistence** — enable `PersistentCacheSettings()`; writes queue and
  replay; deletions propagate as `.removed`.
- **§6 Spark Plan Quota Analysis** — per-action read/write/delete cost table; ~1000×
  headroom at two-user scale; what requires Blaze.
- **§7 Cloud Functions Specification** — none for MVP; deferred `onItemWritten` /
  `reapExpiredCodes` for a Blaze follow-up.
- **§8 Integration Points for `FirebaseService`** — method-by-method mapping from
  today's wrappers.
- **§9 Console Setup Steps** — the Firebase-console prerequisites.
- **Assumptions** — payload-as-JSON-string, auto-generated `spaceId`, redundant
  `coupleSpaceId` left untouched, either-member delete, pair-code read openness,
  client-side expiry, no Cloud Functions in MVP.

### `api-endpoints.md` — `FirebaseService` Swift surface (≈30 KB)
There is **no REST backend**. This spec defines the Swift service layer wrapping the
Firebase iOS SDK — the drop-in replacement for `CloudKitService`.

- **Identity model (read first)** — the dual identity: **Firebase UID** (`String`,
  membership + rules) vs **App profile id** (`UUID`, `UserProfile.id`, payload
  identity). They must never be conflated.
- **FirebaseService — full public surface** — config/role/lifecycle, auth
  integration, space + pairing (create/publish/redeem/join), item CRUD wrappers,
  snapshot-listener sync (`startListening`/`stopListening`/`RemoteChanges`), push +
  reset. New/changed members are flagged inline.
- **Sign in with Apple → Firebase Auth (R1)** — the nonce flow step-by-step; DEBUG
  bypass (`devSignIn()`, offline, `dev-` uid short-circuits all network).
- **Space creation + pair code publish/redeem/join (R3)** — the collapsed invite
  dance; the shareable-link construction; the redeem error mapping; the atomic join
  transaction.
- **Error taxonomy** — `PairCodeError` cases mapped to the exact unchanged copy;
  `shareURLNotReady` removed.
- **Snapshot-listener sync design (R4)** — listener set, per-snapshot handling,
  echo suppression, offline, and the `AppViewModel.syncNow()` shrink.
- **FCM integration approach (R5) + the Blaze boundary** — what ships on Spark
  (token registration + live listeners + local notifications) vs deferred to Blaze;
  why client-to-client FCM is insecure and forbidden.
- **SPM dependencies** — firebase-ios-sdk v11.x; link `FirebaseCore`, `FirebaseAuth`,
  `FirebaseFirestore`, `FirebaseMessaging` to the **app target only** (do not add
  `FirebaseFirestoreSwift`; do not link Firebase into the widget).
- **User-facing prerequisites** — the console + Xcode checklist.
- **Caller migration impact** — the exact call-site changes for `PendingInvite`,
  `AppViewModel`, `CreateSpaceView`, `JoinSpaceView`, `AppDelegate`.
- **Assumptions** — auth session storage, offline DEBUG bypass, invite-link
  transport, `RType` plural values, full-space case, push on Spark, server
  timestamps.

### `ui-components.md` — UI impact of the backend swap (≈16 KB)
This is a backend swap with **no visual redesign** — colors, typography, spacing,
gradients, radii, animations stay pixel-identical. This spec covers only which
*states*, *copy*, and *data plumbing* change, plus accessibility identifiers for
verification.

- **§1 CreateSpaceView** — `createInviteLink()` collapses to one Firestore write;
  `accountStatus()` iCloud pre-flight deleted; iCloud error branches retired.
- **§2 JoinSpaceView** — typed code, `tweli://`, and `https://…?code=` all converge on
  one redemption path (a simplification, not a new state).
- **§3 JoinConfirmView** — `PendingInvite` reshaped to a plain struct; new
  space-full failure mode wired into the join error path.
- **§4 SettingsView** — replace the CloudKit-specific `"iCloud sync … On (mock)"`
  row with a real 3-state sync status; leave/sign-out semantics under Firebase.
- **§5 States/loading/error/empty copy table** — the authoritative copy list;
  retired cases (`quotaExceeded` family, `shareURLNotReady`) and the new
  space-full copy.
- **§6 Intentionally unchanged (do not touch)** — the visual tokens and components to
  leave alone.
- **§7 Accessibility identifiers** — the new `tweli.<view>.<element>` convention for
  verification (none exist in the codebase today).
- **Assumptions** — settings sync status, no leave-space confirmation, invite-link
  format, space-full copy.

---

## Quick stats

| Metric | Value |
|---|---|
| Planning specs | 4 (requirements, database, api-endpoints, ui-components) |
| Backend | Firebase — Firestore + Auth + FCM, Spark (free) plan |
| Firestore top-level collections | 2 (`spaces`, `pairCodes`) |
| Item subcollections per space | 6 (`reminders`, `countdowns`, `letters`, `virtualDates`, `moods`, `pings`) |
| Composite indexes required (MVP) | 0 |
| Cloud Functions (MVP) | 0 (Blaze-only; deferred) |
| Snapshot listeners attached | 7 (6 item subcollections + 1 space doc) |
| New primary service | `FirebaseService` (replaces `CloudKitService`) |
| SPM products linked (app target) | 4 (`FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `FirebaseMessaging`) |
| SPM products in widget target | 0 (local-only handoff preserved) |
| Views with changed states/copy | 4 (`CreateSpaceView`, `JoinSpaceView`, `JoinConfirmView`, `SettingsView`) |
| Console prerequisites (user-facing) | ~10 (see checklist) |
| Data migration | None (pre-launch; no CloudKit production data) |

---

## Key cross-cutting decisions

These decisions span multiple specs. Every implementer should internalize them before
touching code — they are the load-bearing calls the whole migration rests on.

### 1. Pair code IS the invite — no share URL to mint
CloudKit minted a `CKShare` URL asynchronously (the `preparingShare`/`shareWithURL`
backoff-polling race in `CreateSpaceView`). Firebase eliminates this entirely: the
6-char pair code is the document ID of `pairCodes/{code}`, and the shareable link
simply **encodes that code** (`https://<project>.web.app/join?code=7GK4PB`, with
`tweli://join?code=7GK4PB` as the always-present fallback). The invite link and the
pair code become available together, synchronously with a single Firestore write.
Redemption is a direct `getDocument(pairCodes/{code})` — no query, no index. The
alphabet (`23456789ABCDEFGHJKMNPQRSTUVWXYZ`, excludes 0/O/1/I/L), normalization, and
48h expiry are ported verbatim. Consequence: `shareURLNotReady` is retired across
api-endpoints.md and ui-components.md; all three input shapes (typed code, `tweli://`,
`https://…?code=`) converge on one redemption path.

### 2. Dual identity — Firebase UID vs UserProfile UUID (never conflate)
Two identities coexist and are kept strictly separate (api-endpoints.md "Identity
model"):
- **Firebase UID** (`String`, from Firebase Auth) is the canonical membership id — it
  lives on `spaces/{spaceId}.memberUids`, `pairCodes/{code}.createdBy`, and item
  `authorUid`, and it is what **security rules enforce against**.
- **App profile id** (`UUID`, `UserProfile.id`, per-install) stays inside the item
  JSON payloads (`Mood.sentBy`, `Ping.sentTo`, reminder ownership) — **unchanged**.

The Firebase UID never enters a payload. This is what keeps R2's "thin payload blob"
mapping intact and means every feature service's `mergeRemote(_:deletedIDs:)` is
untouched. `role` (owner/participant) is derived from `ownerUid == auth.uid` and still
cached locally for instant UI.

### 3. Snapshot listeners replace change tokens + delta fetch
CloudKit's `fetchChanges()` + `CKServerChangeToken` delta polling is replaced by
Firestore `addSnapshotListener` — one listener per item subcollection plus one on the
space doc (7 total). `.added`/`.modified` deliver payloads; `.removed` delivers
deletions natively (replacing the CloudKit `deletedIDs` bookkeeping); the space-doc
listener surfaces "partner joined". The callback hands back a `RemoteChanges` struct
in the **same shape** `AppViewModel` already merges, so decode+merge wiring is reused
almost verbatim. No `tokenKey(zoneID)` UserDefaults archiving, no
`recordZoneChanges(since:)`. Offline is covered by Firestore's built-in persistent
cache (`PersistentCacheSettings()`), which — unlike CloudKit — never fails on the
user's personal storage quota. A `fetchChanges()`-shaped shim is kept for
pull-to-refresh / first-sync convenience.

### 4. Background push deferred — Blaze-only (Spark plan boundary)
Server-side push on Firestore triggers requires **Cloud Functions**, which require the
paid **Blaze** plan. Therefore true background/killed-app cross-device push (the
CloudKit `CKRecordZoneSubscription` silent-push equivalent, R5) is **deferred**. MVP
delivers:
- **Live sync** via foreground snapshot listeners (open app = live),
- **FCM token registration + storage** now (the only piece a future Blaze function
  needs),
- **Local notifications** (already in the app) for reminder/ping UX while foregrounded.

**Do not** attempt client-to-client FCM sends — the HTTP v1 API needs a
service-account credential that must never ship in the app. The deferred piece is a
Cloud Function `onCreate` trigger that targets the other member's stored token; the
`AppDelegate.didReceiveRemoteNotification` path stays wired so enabling Blaze later is
a pure add with no client change. This is the **only** capability with reduced parity
vs CloudKit, and it is flagged clearly in requirements.md R5, database.md §6/§7, and
api-endpoints.md.

### 5. Atomic max-2 join, enforced twice (rules + transaction)
Joining atomically adds the **second** member with a strict max-2, no-takeover
guarantee. It is enforced structurally in the security rules (`isAtomicJoin`: current
member count exactly 1, result exactly 2, caller not already present, existing member +
owner unchanged) AND via a Firestore client transaction (the friendly path that
retries and surfaces a "space is full" message). A new **"space is full"** user-facing
outcome appears consistently in api-endpoints.md (join error), database.md (rule
guarantee), and ui-components.md §5 (new copy: "This space already has two people. Ask
your partner to send you a fresh invite.") — CloudKit's share-accept flow could not
race this way, so this copy has no pre-migration equivalent.

### 6. Cutover, not dual-run (R6)
Replace CloudKit at the service boundary and retire `CloudKitService`, the iCloud/
CloudKit capability, and the `iCloud.me.adithyan.shalinth.Tweli` container after
verification. No data migration (pre-launch). Keep the widget local-only (R7) — no
Firebase in the widget target.

### Spark-plan prerequisites the user must do in the Firebase console
These block build/runtime and cannot be scripted from the app (full checklist below).
The load-bearing ones: create the project on the **Spark** plan, register the iOS app
with bundle id `me.adithyan.shalinth.Tweli`, add `GoogleService-Info.plist` to the app
target, enable the **Apple** auth provider, create the Firestore database, deploy the
§3 security rules, and upload the **APNs Auth Key** (needed for FCM token minting even
on Spark).

---

## Reading order for implementers

Read top-to-bottom; each step assumes the prior ones.

1. **`requirements.md`** — the seven requirements are the contract. Everything else
   is an elaboration of these.
2. **`database.md` §1–§2** — internalize the Firestore shape (collections, the shared
   item-document schema, IDs) before reading any code-level API.
3. **`api-endpoints.md` "Identity model"** — the Firebase-UID-vs-UUID split shapes
   every method signature and rule. Do not skip it.
4. **`database.md` §3 (Security Rules)** — the rules are the real enforcement boundary
   (membership, pair-code access, atomic join). The service transactions are the
   friendly path on top of these.
5. **`api-endpoints.md` full surface + auth flow + invite flow + sync design** —
   this is the `FirebaseService` build spec. Cross-check `RType` collection strings
   against database.md §2 (plural lowercase: `reminders`, `countdowns`, `letters`,
   `virtualDates`, `moods`, `pings`).
6. **`api-endpoints.md` "Caller migration impact"** — the precise call-site edits in
   `AppViewModel`, `CreateSpaceView`, `JoinSpaceView`, `PendingInvite`, `AppDelegate`.
7. **`ui-components.md`** — the state/copy/plumbing changes and the §5 copy table are
   the acceptance surface for the four affected views; §7 accessibility identifiers
   are what verification drives the flow with.
8. **`database.md` §9 + `api-endpoints.md` prerequisites** — do the console setup
   **before** first run; the app will not build/authenticate without
   `GoogleService-Info.plist` and the enabled Apple provider.

**Suggested implementation sequence** (thin vertical slices, per the project's
incremental-delivery rule):
1. Console setup + SPM Firebase + `FirebaseApp.configure()` in `AppDelegate`.
2. `FirebaseService` skeleton with role/spaceId persistence + Firestore persistence
   settings + the DEBUG offline bypass (`devSignIn()`).
3. Sign in with Apple → Firebase Auth (nonce flow) in `AuthService` +
   `signInWithApple`.
4. Space create + pair-code publish/redeem/join (transaction) + `PairInvite`/
   `PendingInvite` reshape.
5. Item CRUD wrappers (`save*`/`delete*`/`sendPing`) writing the payload document.
6. Snapshot listeners (`startListening`/`RemoteChanges`) + `AppViewModel.syncNow()`
   shrink; verify deletions propagate.
7. FCM token registration (`updateFCMToken`) + `MessagingDelegate` wiring.
8. UI state/copy updates in the four views + accessibility identifiers.
9. Retire `CloudKitService` + remove iCloud/CloudKit capability + verify widget.

---

## Console prerequisites (user must do these by hand)

From database.md §9 and api-endpoints.md "User-facing prerequisites". These block the
build/runtime and cannot be scripted from the app — present them to the user as a
checklist:

1. Create/confirm the Firebase project — keep it on the **Spark (free)** plan.
2. Register an iOS app with bundle id **`me.adithyan.shalinth.Tweli`**. (The widget
   extension does **not** need registering — it isn't a Firebase client, R7.)
3. Download **`GoogleService-Info.plist`** and add it to the **app target** only
   (Build Phases → Copy Bundle Resources). Recommend `.gitignore` + a note on where
   teammates get it.
4. **Authentication → Sign-in method → Apple** — enable the provider. The native
   nonce flow needs nothing further as long as the bundle id matches (no Services ID /
   key / redirect setup).
5. **Firestore Database** — create in Native/production mode; pick a region (permanent).
6. **Deploy security rules** from database.md §3 and the empty
   `firestore.indexes.json` from §4 (`firebase deploy --only
   firestore:rules,firestore:indexes`, or console paste).
7. **Cloud Messaging** — upload the **APNs Authentication Key** (`.p8`) with its Key
   ID + Team ID. Required for FCM token minting even on Spark.
8. **Xcode capabilities** (app target): **Push Notifications** + **Background Modes →
   Remote notifications** (the latter already exists for CloudKit — keep it). Remove
   the **iCloud / CloudKit** capability and the `iCloud.me.adithyan.shalinth.Tweli`
   container after cutover verification (R6).
9. **(Optional) Firebase Hosting** (free on Spark) — deploy a tiny `/join` page +
   `apple-app-site-association` so `https://<project>.web.app/join?code=…` opens the
   app. Skip for a code-only MVP (redeem path is identical; only the tappable-link
   affordance is lost).
10. Call **`FirebaseApp.configure()`** once at launch in
    `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, before
    `registerForRemoteNotifications()`.

---

## Quick reference

### Firestore paths
```
spaces/{spaceId}                                  ← couple space (title, ownerUid, memberUids[≤2], memberNames, createdAt, updatedAt)
spaces/{spaceId}/reminders/{itemId}               ← ReminderItem     (payload JSON string)
spaces/{spaceId}/countdowns/{itemId}              ← CountdownItem
spaces/{spaceId}/letters/{itemId}                 ← OpenWhenLetter
spaces/{spaceId}/virtualDates/{itemId}            ← VirtualDateItem
spaces/{spaceId}/moods/{itemId}                   ← MoodStatus
spaces/{spaceId}/pings/{itemId}                   ← MissingYouPing
pairCodes/{code}                                  ← invite code (spaceId, spaceTitle, createdBy, createdByName, expiresAt+48h, createdAt)
```
Item document shape: `{ payload: <JSON string>, authorUid: <uid>, updatedAt: serverTimestamp, schemaVersion: 1 }`.
Item doc ID = model's `id.uuidString`. Pair-code doc ID = the normalized 6-char code.

### `RType` collection constants (must match database.md paths)
`reminders`, `countdowns`, `letters`, `virtualDates`, `moods`, `pings` (plural, lowercase).

### Pair-code rules
- Alphabet: `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (no 0/O/1/I/L), 6 chars.
- `normalizePairCode(raw)` = uppercase + keep only alphabet chars (`7gk-4pb` → `7GK4PB`).
- Expiry: 48h, enforced client-side on redemption.

### Key files touched (from the specs)
| File | Change |
|---|---|
| `Tweli/Services/CloudKitService.swift` | Retired after cutover |
| `Tweli/Services/FirebaseService.swift` (new) | New backend boundary |
| `Tweli/Services/AuthService.swift` | Nonce flow → Firebase Auth credential exchange |
| `Tweli/App/AppViewModel.swift` | Drop `import CloudKit`; `syncNow()` → start listeners; join via `joinSpace` |
| `Tweli/App/AppDelegate.swift` | `FirebaseApp.configure()`; drop CKShare accept; add FCM `MessagingDelegate` |
| `Tweli/Models/PendingInvite.swift` | Reshape from `CKShare.Metadata` to plain struct / `PairInvite` |
| `Tweli/Views/Room/CreateSpaceView.swift` | Remove iCloud preflight + quota branch; `createShare` → `createSpace` |
| `Tweli/Views/Room/JoinSpaceView.swift` | `normalizePairCode` via new service; unify link/code redemption |
| `Tweli/Views/Room/JoinConfirmView.swift` | Reshaped `PendingInvite`; space-full failure path |
| `Tweli/Views/Settings/SettingsView.swift` | Replace `"iCloud sync … On (mock)"` with 3-state sync status |
| `TweliWidget` / `WidgetDataService` | Verify local-only handoff; no Firebase (R7) |

### SPM
`https://github.com/firebase/firebase-ios-sdk`, `.upToNextMajor(from: "11.0.0")`.
App target links: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`,
`FirebaseMessaging`. Do **not** add `FirebaseFirestoreSwift` (absorbed into
`FirebaseFirestore` in v11). Widget links **none**.

### DEBUG bypass (project convention — kept)
`devSignIn()` sets a synthetic `dev-<uuid>` uid, `accountAvailable = true`, and makes
**no** network call. `FirebaseService` short-circuits all Firestore reads/writes and
listeners when `currentUid` has the `dev-` prefix — debug builds run entirely on
`MockData` + local stores, `#if DEBUG`-gated so it is compile-time excluded from
release.

---

## Next steps checklist

- [ ] Generate `tasks.md` (task breakdown) — not yet present in this feature folder.
- [ ] Complete the console prerequisites (above) — blocks first build/run.
- [ ] Implement `FirebaseService` per api-endpoints.md, verifying `RType` strings
      match database.md paths.
- [ ] Deploy the §3 security rules; test atomic join + space-full path.
- [ ] Verify deletion propagation through `.removed` snapshot changes.
- [ ] Retire `CloudKitService` + remove iCloud/CloudKit capability + container (R6).
- [ ] Confirm the widget still works local-only (R7).
- [ ] Flag the Blaze background-push follow-up (R5) for a future feature.
