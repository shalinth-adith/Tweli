# DECISIONS.md — Tweli project-wide architectural decisions

Seeded 2026-07-12 from the 18-firebase-migration planning cycle (the project predates
this planning system; decisions before that live in git history). Amendments only via
dated `### Amendment` blocks.

## 1. Auth
Sign in with Apple is the only auth method, exchanged for a Firebase Auth session via
the native nonce flow (no login forms, no passwords). Firebase UID is the canonical
identity for membership and security rules. **Dev bypass (§14 convention)**: `#if DEBUG`
client-side mock session in `AuthService` — debug builds land authenticated with no
network call; compile-time excluded from release.

## 2. Multi-tenancy / data isolation
One Firestore `spaces/{spaceId}` document per couple; access limited to the ≤2 UIDs in
`memberUids` by security rules. Join is atomic (transaction + `isAtomicJoin` rule):
membership can only go 1→2, never a takeover, never a third member.

## 3. Backend
No custom server, no REST API. The backend is the Firebase iOS SDK (Firestore +
FirebaseAuth + FirebaseMessaging) behind a single Swift boundary: `FirebaseService`
(replaces `CloudKitService`, same call surface). Spark (free) plan only — anything
requiring Blaze (Cloud Functions, server-side push triggers) is deferred and must be
flagged, never silently added.

## 4. Data model
Thin-payload documents: `{ payload: JSON-encoded Codable model as string, authorUid:
Firebase UID of writer, updatedAt: serverTimestamp, schemaVersion: 1 }`, doc ID =
`item.id.uuidString`. App-level `UserProfile.id` UUIDs stay inside payloads; Firebase
UIDs never enter payloads (dual-identity rule). Collection names are plural lowercase:
`reminders`, `countdowns`, `letters`, `virtualDates`, `moods`, `pings`, plus
`pairCodes/{code}`.

## 5. Sync & offline
Firestore snapshot listeners (one per item subcollection + one on the space doc) replace
polling/change tokens; deletions propagate via `.removed` changes. Firestore persistent
cache handles offline. Background cross-device push is deferred (Blaze); FCM token
registration ships now (`fcmTokens` map on the space doc).

## 6. Deletions
Item deletes are hard deletes of the item document (two-person private data, no
compliance retention need). Space deletion is forbidden by rules; "leave space" is
local-only state clearing (`FirebaseService.reset()`).

## 7. Invites
6-char pair code (alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ`, 48h expiry, code = doc ID)
is the invite. Links (`tweli://join?code=…`, optional Hosting universal link) merely
carry the code. Error taxonomy: `notFound / expired / badShareURL / spaceFull / network`
with fixed user-facing copy (see api-endpoints.md §Error taxonomy).

## 13. Placeholder safety
No realistic fake data in production paths; debug-gated mocks only (`#if DEBUG`).
Dev-only fake values use the project's greppable placeholder prefix convention (see
agent-workflow rules — the all-caps PLACEHOLDER prefix followed by an underscore).
Empty states render "Not set"/empty, never fake values.

## 14. Auth bypass for testing
iOS-only project: compile-time `#if DEBUG` mock session (per §1). No dev-login HTTP
endpoint exists because there is no server. Verification drives debug builds on the
simulator, which land authenticated automatically.
