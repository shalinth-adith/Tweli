# Feature: Firebase Migration (CloudKit → Firebase)

## Problem

Tweli currently syncs the couple space via CloudKit (`Tweli/Services/CloudKitService.swift`).
CloudKit stores data in the **user's** iCloud private database, so any user whose
personal iCloud storage is full gets `CKError.quotaExceeded` on every write — the app
is unusable for them from the very first step (creating a space). This was observed
in real testing (see screenshot evidence, 2026-07-11). There is no API to detect or
prevent this, and a large share of iPhone users sit at 100% of the free 5 GB plan.

## Goal

Replace the CloudKit sync layer with Firebase (Firestore + Firebase Auth + FCM) so
storage counts against the project quota instead of the user's iCloud. Users must
never be blocked by their personal storage. The user already has a Firebase account;
a Firebase project needs to be created/configured for Tweli (bundle id
`me.adithyan.shalinth.Tweli`, plus the widget extension target).

## Current architecture (what must be replaced)

`CloudKitService` is the single backend boundary. Feature services
(`ReminderService`, `CountdownService`, `OpenWhenLetterService`, `VirtualDateService`,
`MoodService`, `MissingYouService`, `CoupleSpaceService`) call typed wrappers on it.

Capabilities to reproduce:

1. **Couple space + roles** — one shared space per couple; `owner` created it,
   `participant` joined. Role persisted locally (`tweli.ck.role`).
2. **Invite flow** (`CreateSpaceView`, `JoinSpaceView`, `JoinConfirmView`):
   - Owner creates space → gets a shareable **invite link** + **6-char pair code**
     (alphabet excludes 0/O/1/I/L; codes expire after 48h; normalization strips
     separators and lowercase).
   - Partner redeems code or taps link → confirm sheet → joins space.
   - Owner can see the partner's display name once joined
     (`acceptedParticipantName()`).
3. **Item sync** — 6 Codable item types stored as JSON payloads: Reminder,
   Countdown, Letter (OpenWhen), VirtualDate, Mood, Ping (MissingYou). CRUD =
   save/delete keyed by item UUID. Fetch = delta changes since last sync
   (`fetchChanges()` returns payloads-by-type + deleted IDs).
4. **Push wake-up** — silent push on remote changes (`registerSubscription()`),
   handled in `AppDelegate`.
5. **Reset** — leave/clear space state.

## Requirements

### R1 — Firebase Auth with Sign in with Apple
- Keep the existing Sign in with Apple UX (`AuthService.swift`); exchange the Apple
  credential for a Firebase Auth session (nonce flow). No new login screens.
- Firebase UID becomes the canonical user id; keep the display-name persistence.
- Keep the existing `#if DEBUG` client-side auth bypass working (project convention:
  debug builds land authenticated with a mock session, no network).

### R2 — Firestore data model
- `spaces/{spaceId}` — title, ownerUid, memberUids (max 2), createdAt.
- Item subcollections under the space (one per item type) storing the same Codable
  JSON payloads (or mapped fields — planner's choice; keep the mapping as thin as
  today's `payload` blob approach unless there's a strong reason).
- `pairCodes/{code}` — spaceId, spaceTitle, expiresAt (48h), createdBy. Same code
  alphabet and normalization as today.
- Security rules: only the 2 member UIDs can read/write a space and its
  subcollections; pair codes readable for redemption but only writable by their
  creator; joining atomically adds the second member (max 2, no takeover).

### R3 — Invite flow parity
- Owner: create space → immediately get pair code + shareable link (link can encode
  the pair code — no server-minted URL wait, unlike CKShare).
- Partner: redeem typed code OR deep link → same confirm sheet → join.
- Same user-facing error cases as `PairCodeError` today: notFound / expired /
  badShareURL / network — reuse the friendly copy.
- Owner sees partner's name after join.

### R4 — Sync parity
- `FirebaseService` (new) exposes the same surface the feature services use today
  (`saveReminder`, `deleteReminder`, `saveCountdown`, … `sendPing`, `fetchChanges`
  or listener-based equivalent, `reset`).
- Prefer Firestore snapshot listeners for live sync (replaces change tokens +
  manual delta fetch). Deletions must propagate.
- Offline: Firestore's built-in persistence should cover the current behavior.

### R5 — Push notifications
- FCM silent/data push to wake the partner's app on changes (parity with the
  CloudKit zone subscription), and it should also serve the existing
  "Send love" ping UX. May require a Cloud Function trigger (stay on free tier —
  note: Cloud Functions require the Blaze plan; if so, prefer FCM directly from
  client-triggered flows or defer server-side push to a follow-up and rely on
  foreground listeners + existing local notifications for MVP).

### R6 — Cutover, not dual-run
- Replace CloudKit at the service boundary; delete/retire `CloudKitService` usage
  once verification passes. No data migration needed (app is pre-launch; no
  production users on CloudKit).
- CloudKit entitlements/container can be removed after cutover.

### R7 — Widget
- `TweliWidget` + `WidgetDataService` must keep working (they read shared local
  data; verify the data handoff path doesn't depend on CloudKit types).

## Constraints

- SwiftUI app, iOS. SPM for the Firebase iOS SDK (latest v11+).
- Stay within the Firebase Spark (free) plan. Flag anything that requires Blaze.
- Firebase project setup steps that need the console (creating the iOS app,
  downloading `GoogleService-Info.plist`, enabling Auth provider, Firestore,
  deploying security rules) must be documented as explicit user-facing steps.
- Follow existing code style; `CloudKitService.swift` shows the expected level of
  inline documentation and logging.

## Out of scope

- Migrating existing CloudKit data (none in production).
- Android / web clients.
- Paid plan features (Cloud Functions on Blaze) — flag but don't require.
