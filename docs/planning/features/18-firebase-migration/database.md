# Firestore Data Model — Firebase Migration (CloudKit → Firebase)

**Feature**: `18-firebase-migration`
**Backend**: Firebase (Firestore + Firebase Auth + FCM)
**Mode**: MVP
**Author**: @firebase-database-architect
**Date**: 2026-07-11

This document is the authoritative Firestore schema, security-rules, index, offline,
and quota specification for replacing `CloudKitService` with Firebase. It is written
for the `firebase-developer` who will build `FirebaseService` (the new backend
boundary that exposes the same surface the feature services use today).

The guiding principle from R2 is **keep the mapping as thin as today's CloudKit
`payload` blob approach**. In CloudKit every item is a `CKRecord` whose only real
field is `payload = JSONEncoder().encode(item)`. We reproduce that one-to-one: every
item document stores the Codable model as a JSON string in a `payload` field, plus a
tiny set of denormalized root fields that the security rules and listeners need.

---

## 1. Design Overview

### CloudKit → Firestore mapping

| CloudKit concept | Firestore equivalent |
|---|---|
| Custom shared zone `CoupleZone` | Document `spaces/{spaceId}` |
| Root `CoupleSpace` record | Fields on the `spaces/{spaceId}` document |
| `CKShare` + `publicPermission = .readWrite` | `memberUids` array on the space + security rules |
| Owner reads private DB / participant reads shared DB | Both members read/write the **same** `spaces/{spaceId}` document tree |
| Child item record (`payload` blob), `setParent(root)` | Document in a per-type subcollection under the space |
| `PairCode` record in the **public** DB (code = record name) | Document `pairCodes/{code}` (code = document ID) |
| `recordName = item.id.uuidString` | `documentID = item.id.uuidString` |
| `fetchChanges()` + `CKServerChangeToken` delta | Firestore **snapshot listener** (`addSnapshotListener`) |
| Deleted record IDs in delta | `DocumentChange.type == .removed` from the listener |
| `CKRecordZoneSubscription` silent push | FCM data message (deferred — see §7 / R5) |
| `role` (owner/participant) in UserDefaults | Derived from `ownerUid == auth.uid`; still cached locally for UI |

The biggest structural win: CloudKit forced an owner/participant split across two
databases (private vs shared) with zone discovery, change tokens, and share-URL
minting races. Firestore collapses all of that into a single shared document tree
that both members address by the same path, with live listeners instead of manual
delta polling.

### ID strategy

- **`spaceId`** — auto-generated Firestore ID (`collection.document()`), stored back
  onto the space as convenience and used as the value inside pair codes and deep
  links. It is **not** the couple's `CoupleSpace.id` UUID; see Assumptions.
- **Item document IDs** — the model's own `id.uuidString` (upper/lowercased as Swift
  emits it). This is a straight port of CloudKit's `recordName = id.uuidString` and
  makes `save` an idempotent `setData(merge:)` keyed by the item UUID, exactly like
  today's "fetch-or-create by record ID" logic.
- **`pairCodes/{code}`** — the 6-char code itself is the document ID, so redemption is
  a direct `getDocument` by ID with zero query/index setup, mirroring the CloudKit
  "code AS record name" trick.

---

## 2. Collections & Document Schemas

```
spaces (collection)
└── {spaceId} (document)              ← the couple space (was: CoupleZone + root record)
    ├── reminders     (subcollection) → {itemId} docs   (ReminderItem)
    ├── countdowns    (subcollection) → {itemId} docs   (CountdownItem)
    ├── letters       (subcollection) → {itemId} docs   (OpenWhenLetter)
    ├── virtualDates  (subcollection) → {itemId} docs   (VirtualDateItem)
    ├── moods         (subcollection) → {itemId} docs   (MoodStatus)
    └── pings         (subcollection) → {itemId} docs   (MissingYouPing)

pairCodes (collection)
└── {code} (document)                 ← 6-char invite code (was: public-DB PairCode)
```

### 2.1 `spaces/{spaceId}`

The single source of truth for the couple. Both members read and write this document.

| Field | Type | Required | Notes |
|---|---|---|---|
| `title` | string | yes | Space name, e.g. "Us 💞". 1–100 chars. Was `CoupleSpace.title`. |
| `ownerUid` | string | yes | Firebase UID of the creator (was `role == .owner`). Immutable after create. |
| `memberUids` | array<string> | yes | Firebase UIDs of members. **Max length 2.** Contains only `ownerUid` at creation; the partner is appended atomically on join. Used by security rules for access control. |
| `memberNames` | map<string,string> | yes | `uid → displayName`. Lets the owner render the partner's name after join (replaces `acceptedParticipantName()`). Each member writes their own entry. |
| `createdAt` | timestamp | yes | `FieldValue.serverTimestamp()`. Was `CoupleSpace.createdAt`. |
| `updatedAt` | timestamp | yes | `FieldValue.serverTimestamp()` on every write; drives a lightweight "space changed" listener if needed. |

`spaces/{spaceId}` intentionally has **no** array of items — items live in
subcollections (unbounded lists must never be arrays; 1 MB document cap). The space
document stays tiny (well under 1 KB).

### 2.2 Item subcollections — shared schema

All six item subcollections share one document shape. This is the "thin payload"
port of the CloudKit record:

| Field | Type | Required | Notes |
|---|---|---|---|
| `payload` | string | yes | `JSONEncoder().encode(item)` decoded to a UTF-8 string. The entire Codable model. Client decodes with `JSONDecoder`. This is the CloudKit `payload` blob, verbatim. |
| `authorUid` | string | yes | Firebase UID of the writer — always `Auth.auth().currentUser.uid` at save time, **never** copied from the payload (`createdBy`/`sentBy`/`userId` are app-level UUIDs, a different identity space). The `validItem` rule requires `authorUid == request.auth.uid`, so any other value is rejected. Enables rule checks and per-author UI without decoding the blob. |
| `updatedAt` | timestamp | yes | `FieldValue.serverTimestamp()`. Sort key for listeners and "latest mood" queries. Replaces client-side timestamps to avoid clock skew. |
| `schemaVersion` | number | yes | `1`. Cheap forward-compat hook if a model changes shape later. |

Why a JSON **string** and not a native Firestore map: parity and thinness. The client
code becomes `try encoder.encode(item)` → `String(data:encoding:)`, which is a one-line
change from today's `JSONEncoder().encode(item) as CKRecordValue`. It also sidesteps
`Date`/`UUID`/enum re-mapping into Firestore-native types for six models. The tradeoff
(the console shows an opaque JSON string and you cannot server-query inside the blob) is
irrelevant here: this is a two-person app that always reads an entire subcollection via
a listener and filters/sorts client-side. See Assumptions for the reconsider-if signal.

#### Per-type model reference (what's inside `payload`)

Every model is `Codable` and already carries its own `id: UUID` used as the document ID.

| Subcollection | Model | Doc ID | Payload author field (app UUID — informational only; `authorUid` is always the writer's Firebase UID) | Space link inside payload |
|---|---|---|---|---|
| `reminders` | `ReminderItem` | `id.uuidString` | `createdBy` | `coupleSpaceId` |
| `countdowns` | `CountdownItem` | `id.uuidString` | `createdBy` | `coupleSpaceId` |
| `letters` | `OpenWhenLetter` | `id.uuidString` | `createdBy` | `coupleSpaceId` |
| `virtualDates` | `VirtualDateItem` | `id.uuidString` | `createdBy` | `coupleSpaceId` |
| `moods` | `MoodStatus` | `id.uuidString` | `userId` | *(none — see note)* |
| `pings` | `MissingYouPing` | `id.uuidString` | `sentBy` | `coupleSpaceId` |

Note on `MoodStatus`: it has `userId` but **no** `coupleSpaceId` field. The space
context is fully carried by the document path (`spaces/{spaceId}/moods/...`), so no
model change is required — this is exactly why path-scoping is cleaner than the
CloudKit flat-zone approach. The `payload.coupleSpaceId` fields on the other five
models are also now redundant with the path, but we keep them untouched to avoid model
churn (R2 says keep mapping thin; changing the models is not thin).

### 2.3 `pairCodes/{code}`

Direct port of the CloudKit public-DB `PairCode` record. The document ID is the
normalized 6-char code, so redemption is `getDocument(pairCodes/{code})`.

| Field | Type | Required | Notes |
|---|---|---|---|
| `spaceId` | string | yes | The `spaces/{spaceId}` this code joins. (CloudKit stored a `shareURL`; we store the space ID directly — no URL to mint.) |
| `spaceTitle` | string | yes | Denormalized so the confirm sheet shows the space name **without** first reading the space (a non-member cannot read the space document under the rules). Was `PairCode.spaceTitle`. |
| `createdBy` | string | yes | Firebase UID of the owner who published the code. Only this UID may update/delete the code (rules). |
| `expiresAt` | timestamp | yes | `now + 48h`. Was `PairCode.expiresAt` (48h). |
| `createdAt` | timestamp | yes | `FieldValue.serverTimestamp()`. |

**Code generation & normalization — unchanged from `CloudKitService`:**

- Alphabet: `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (excludes `0/O`, `1/I/L`). 6 chars.
- `normalizePairCode(raw)` = uppercase, keep only alphabet chars (strips `-`, spaces,
  lowercases). `"7gk-4pb"` and `"7GK 4PB"` both resolve to `7GK4PB`.
- Reuse-if-unexpired: before publishing a new code, the owner checks its locally
  cached code and, if its `pairCodes/{cached}` doc still exists and `expiresAt > now`,
  returns the same code (parity with today's `publishPairCode` reuse path).

> Deep-link parity (R3): the shareable link encodes the code directly, e.g.
> `https://tweli.app/join/{CODE}`. No server round-trip to mint a URL (the CloudKit
> `CKShare` URL race in `shareWithURL()` is gone entirely). Both the typed code and the
> link resolve through the same `pairCodes/{code}` lookup.

---

## 3. Security Rules

Complete `firestore.rules`. The three hard requirements from R2/R3 are encoded here:
(1) only the ≤2 member UIDs can read/write a space and its subcollections; (2) pair
codes are world-readable for redemption but writable only by their creator; (3) join
atomically adds the **second** member with a strict max-2, no-takeover guarantee.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ---- Helpers ----
    function isSignedIn() {
      return request.auth != null;
    }

    // Reads the space doc to check membership. One document read, billed to the caller.
    function spaceData(spaceId) {
      return get(/databases/$(database)/documents/spaces/$(spaceId)).data;
    }

    function isMember(spaceId) {
      return isSignedIn()
        && request.auth.uid in spaceData(spaceId).memberUids;
    }

    // ---- spaces/{spaceId} ----
    match /spaces/{spaceId} {

      // Only the two members can read the space.
      allow get, list: if isSignedIn()
        && request.auth.uid in resource.data.memberUids;

      // CREATE: creator seeds a solo space. They must be the owner AND the only member.
      allow create: if isSignedIn()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.memberUids == [request.auth.uid]
        && request.resource.data.memberNames.keys().hasOnly([request.auth.uid])
        && request.resource.data.title is string
        && request.resource.data.title.size() >= 1
        && request.resource.data.title.size() <= 100;

      // UPDATE — two allowed shapes:
      //  (a) JOIN: a non-member atomically becomes the 2nd member (max 2, no takeover).
      //  (b) MEMBER EDIT: an existing member updates title/memberNames/updatedAt only.
      allow update: if isSignedIn() && (
        isAtomicJoin(spaceId) || isMemberEdit(spaceId)
      );

      // Never delete the space from the client (leave() clears local state only).
      allow delete: if false;

      // (a) Atomic join: caller is NOT currently a member, space currently has exactly
      // one member, result has exactly two, the incoming caller is the new member, the
      // original member and owner are preserved, and no other space state is altered.
      function isAtomicJoin(spaceId) {
        return
          !(request.auth.uid in resource.data.memberUids)
          && resource.data.memberUids.size() == 1
          && request.resource.data.memberUids.size() == 2
          && request.auth.uid in request.resource.data.memberUids
          && resource.data.memberUids[0] in request.resource.data.memberUids
          && request.resource.data.ownerUid == resource.data.ownerUid
          && request.resource.data.title == resource.data.title
          && request.resource.data.createdAt == resource.data.createdAt
          // Joiner may add only their own name entry to memberNames.
          && request.resource.data.memberNames.keys().hasOnly(
               resource.data.memberNames.keys().concat([request.auth.uid]))
          && request.resource.data.memberNames[request.auth.uid] is string;
      }

      // (b) Existing member edits metadata; membership + owner are frozen.
      function isMemberEdit(spaceId) {
        return
          request.auth.uid in resource.data.memberUids
          && request.resource.data.memberUids == resource.data.memberUids
          && request.resource.data.ownerUid == resource.data.ownerUid
          && request.resource.data.createdAt == resource.data.createdAt
          && request.resource.data.title is string
          && request.resource.data.title.size() >= 1
          && request.resource.data.title.size() <= 100;
      }

      // ---- Item subcollections (all six share identical rules) ----
      match /{itemType}/{itemId} {
        // Restrict to the six known subcollections; reject anything else.
        function isKnownItemType() {
          return itemType in
            ['reminders','countdowns','letters','virtualDates','moods','pings'];
        }

        function validItem() {
          return request.resource.data.payload is string
            && request.resource.data.payload.size() <= 100000   // ~100 KB guard, well under 1 MB
            && request.resource.data.authorUid == request.auth.uid
            && request.resource.data.schemaVersion is int;
        }

        allow read: if isKnownItemType() && isMember(spaceId);

        allow create, update: if isKnownItemType()
          && isMember(spaceId)
          && validItem();

        // Either member may delete any item (matches CloudKit shared-zone behavior,
        // where both partners could delete records in the shared hierarchy).
        allow delete: if isKnownItemType() && isMember(spaceId);
      }
    }

    // ---- pairCodes/{code} ----
    match /pairCodes/{code} {
      // Redemption must work for the not-yet-a-member partner, so any signed-in user
      // may read a code by ID. Codes carry no private data beyond a space title +
      // spaceId; a guessed code still cannot join without passing the space join rule.
      allow get: if isSignedIn();

      // Do NOT allow listing/enumeration of all codes.
      allow list: if false;

      allow create: if isSignedIn()
        && request.resource.data.createdBy == request.auth.uid
        && request.resource.data.spaceId is string
        && request.resource.data.spaceTitle is string
        && request.resource.data.expiresAt is timestamp;

      // Only the creator may refresh/delete their own code.
      allow update, delete: if isSignedIn()
        && resource.data.createdBy == request.auth.uid;
    }
  }
}
```

### Rule design notes

- **Max-2 / no-takeover** is enforced structurally in `isAtomicJoin`: the update is
  only valid when the current member count is exactly 1 and the result is exactly 2,
  the caller is not already present, and the pre-existing member + owner are unchanged.
  There is no rule shape that lets a third UID in or that swaps an existing member out.
- **The join is genuinely atomic** on the client via a Firestore **transaction**:
  read `spaces/{spaceId}`, verify `memberUids.size() == 1`, then
  `update(memberUids: FieldValue.arrayUnion(uid), memberNames.{uid}: name)`. Two
  partners racing to join the same solo space: the transaction retries, the second one
  sees `size() == 2`, and the rule rejects it — no lost update, no third member.
- **Expiry is enforced client-side** on redemption (read the code, compare
  `expiresAt` to `now`, throw the friendly `expired` copy) exactly as CloudKit did.
  Rules do not gate reads on expiry because rules cannot cheaply compare to "now" for
  a read without extra plumbing; the security boundary that matters (who can *join*) is
  the space rule, not the code read.
- **`get()` in rules costs a billed read.** Each item read/write triggers one
  `spaceData(spaceId)` document read for the membership check. At two-user scale this
  is negligible (see §6), but it is why the space document is kept tiny.

---

## 4. Composite Indexes

**None required for MVP.** Every query is single-collection and single-field-ordered:

- Item listeners: `spaces/{spaceId}/{type}` ordered by `updatedAt` (single-field;
  Firestore auto-creates ascending/descending single-field indexes).
- `pairCodes/{code}`: direct `getDocument` by ID — no query, no index.
- No collection-group queries (we always scope to one known `spaceId`), so no
  collection-group index is needed.

`firestore.indexes.json` ships effectively empty:

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

If a future screen adds a multi-field query (e.g. `where(status ==).order(by: date)`
across a subcollection), Firestore's runtime error will include a console link to
create the exact composite index — add it then, not speculatively.

---

## 5. Offline Persistence

Firestore's on-device cache covers the current CloudKit offline behavior (R4) with no
custom change-token bookkeeping:

- **Enable persistence explicitly** in `FirebaseService` init. On the modern SDK:
  set `FirestoreSettings.cacheSettings = PersistentCacheSettings()` (persistent cache
  is the default on iOS, but set it explicitly so intent is clear and the size is
  controlled). Default cache size (100 MB) is far more than a two-person text-only
  dataset needs; leaving the default is fine.
- **Writes queue offline** and replay on reconnect — parity with the app continuing to
  function without network. Listeners fire immediately from cache, then reconcile.
- **`updatedAt` server timestamps** resolve to an estimate locally
  (`ServerTimestampBehavior.estimate`) and settle to the true server value on sync;
  keep this in mind if any UI sorts strictly by `updatedAt` right after a local write.
- **Deletions propagate** through the same listener as `DocumentChange.type == .removed`,
  including offline-queued deletes — this replaces the CloudKit `deletedIDs` delta.

No manual change tokens, no `tokenKey(zoneID)` UserDefaults archiving, no
`recordZoneChanges(since:)` — all removed.

---

## 6. Spark (Free) Plan Quota Analysis

Spark daily/total limits vs. this app's realistic usage (a single couple = 2 devices):

| Spark limit | Cap | Tweli usage per couple/day | Headroom |
|---|---|---|---|
| Document reads | 50,000/day | Dozens–low hundreds (initial listener load of all items + one read per change + one `get()` per item write for the membership rule) | ~1000× |
| Document writes | 20,000/day | Tens (each saved reminder/mood/ping = 1 write) | ~1000× |
| Document deletes | 20,000/day | A handful | Enormous |
| Stored data | 1 GiB | Text-only JSON payloads; a heavy couple is < 1 MB | ~1000× |
| Network egress | 10 GiB/month | Tiny (text) | Enormous |

**Cost-per-action** (Firestore bills per operation):

| User action | Reads | Writes | Deletes | Notes |
|---|---|---|---|---|
| Create space | 0 | 1 | 0 | write `spaces/{spaceId}` |
| Publish pair code | 0–1 | 1 | 0 | optional reuse-check read + 1 write |
| Redeem code + join | 1 (code) + 1 (txn read of space) | 1 (join update) | 0 | plus 1 rule `get()` billed on the update |
| Save any item | 1 (rule `get()` of space) | 1 | 0 | idempotent `setData(merge:)` |
| Delete any item | 1 (rule `get()`) | 0 | 1 | |
| Live sync tick | 1 per changed doc | 0 | 0 | snapshot listener |

Even a couple hammering the app all day stays three orders of magnitude under Spark
limits. **Storage counting against the project quota instead of the user's iCloud is
the entire point of this migration (R1 problem statement) — and 1 GiB of text is
effectively unreachable for two people.**

### What requires Blaze (flag, don't build for MVP)

- **Cloud Functions** (any Firestore trigger, scheduled cleanup, server-sent FCM) are
  **Blaze-only**. Do **not** put anything on the critical path that needs them.
- Therefore **server-pushed silent notifications** to a backgrounded partner (the
  CloudKit `CKRecordZoneSubscription` equivalent, R5) are **deferred**. For MVP:
  - Live updates come from **foreground snapshot listeners** (open app = live).
  - The "Send love" ping and reminder alerts continue to fire as **local
    notifications** (already in the app) when the item arrives via the listener while
    foregrounded.
  - True background wake-up (partner's app closed) is a follow-up that needs either a
    Blaze Cloud Function calling FCM, or a minimal external server holding the FCM
    server key. Flagged for the api/service planner.
- **Optional Spark-friendly cleanup**: expired `pairCodes` have no server to reap them
  on Spark. They are harmless (redemption checks `expiresAt` and rejects), tiny, and
  overwritten on the owner's next publish. Leave them; do not build a Blaze scheduled
  function for MVP.

---

## 7. Cloud Functions Specification

**None for MVP** — Spark plan forbids them (see §6). All logic lives client-side:

- Atomic join → Firestore client **transaction** (not a callable function).
- Pair-code generation/normalization → client (unchanged from `CloudKitService`).
- Membership enforcement → **security rules** (not a function).

Deferred to a Blaze follow-up (documented for whoever revisits R5):

| Function | Type | Trigger | Purpose |
|---|---|---|---|
| `onItemWritten` | Firestore trigger | `spaces/{spaceId}/{type}/{itemId}` onWrite | Send FCM data message to the *other* member's device tokens to wake a backgrounded app. |
| `reapExpiredCodes` | Scheduled | daily | Delete `pairCodes` where `expiresAt < now` (cosmetic; not required). |

If/when Blaze is enabled, add a `spaces/{spaceId}` field `memberTokens: map<uid,
fcmToken>` (each client writes its own token) so `onItemWritten` can target the
partner without a users collection.

---

## 8. Integration Points for `FirebaseService`

The developer building `FirebaseService` should preserve this surface (from R4). Names
map 1:1 to today's `CloudKitService` wrappers:

- `saveReminder / deleteReminder`, `saveCountdown / deleteCountdown`, `saveLetter`,
  `saveVirtualDate`, `saveMood`, `sendPing` → `setData(merge:)` / `delete()` on
  `spaces/{spaceId}/{type}/{item.id.uuidString}`, writing `{payload, authorUid,
  updatedAt: serverTimestamp, schemaVersion: 1}`.
- `fetchChanges()` → replaced by **one `addSnapshotListener` per subcollection** (six
  listeners), surfacing `.added/.modified/.removed` document changes. Deletions flow
  through `.removed`. Keep a `fetchChanges()`-shaped adapter if the feature services
  are easier to leave untouched, but prefer wiring the listeners.
- Space/role: `ownerUid == auth.uid` derives `role`; still cache locally for instant UI.
- `createCoupleSpace` → transaction/`setData` creating `spaces/{spaceId}` with the
  creator as sole member.
- Pair codes: `publishPairCode(spaceId:, spaceTitle:)` writes `pairCodes/{code}`;
  `redeemPairCode(raw:)` normalizes, `getDocument`, maps errors to the existing
  `PairCodeError` cases (`notFound` = missing doc, `expired` = `expiresAt < now`,
  `network` = transient/other, drop `badShareURL`/`shareURLNotReady` — no share URL
  anymore, or repurpose `badShareURL` for a malformed/space-missing code).
- `reset()` → clear local role/space cache (does not delete the remote space; delete is
  disabled in rules).

`PendingInvite` (currently wraps `CKShare.Metadata`) must be reworked to wrap the
redeemed `pairCodes/{code}` data (`spaceTitle`, `spaceId`, inviter name from
`memberNames[ownerUid]`) — flagged for the api/service and UI planners.

---

## 9. Console Setup Steps (user-facing, R1/R6 constraints)

These require the Firebase Console and cannot be scripted from the app:

1. Create/confirm a Firebase project for Tweli.
2. Add an iOS app with bundle id `me.adithyan.shalinth.Tweli` **and** register the
   widget extension target's bundle id (R7) if it will use Firebase directly.
3. Download `GoogleService-Info.plist` and add it to the app target (and widget target
   if applicable).
4. **Authentication** → enable **Sign in with Apple** provider (R1 nonce flow).
5. **Firestore Database** → create in production mode, pick a region.
6. Deploy the security rules from §3 (`firestore.rules`) and the empty
   `firestore.indexes.json` from §4 (`firebase deploy --only firestore:rules,firestore:indexes`).
7. (Deferred/Blaze) Cloud Messaging APNs key upload — only needed when background push
   is implemented; not required for the MVP foreground-listener flow.

---

## Assumptions

Documented per auto-mode rules (no `AskUserQuestion`; MVP mode). Each is a judgment
call the developer/user can override.

- **[Payload representation]** Chose a **JSON string `payload` field** over a native
  Firestore map for all six item types. Reason: R2 explicitly favors keeping the
  mapping "as thin as today's `payload` blob approach," and the app never
  server-queries inside an item — it always listens to a whole subcollection and
  filters client-side. Reconsider only if a future feature needs Firestore-side
  `where()` filtering on a field currently inside the blob.
- **[`spaceId` identity]** Chose an **auto-generated Firestore document ID** for
  `spaces/{spaceId}` rather than reusing `CoupleSpace.id.uuidString`. Reason: the
  space ID is now the value inside pair codes and deep links, and an auto ID avoids
  coupling the remote key to a client-minted UUID; the client keeps its `CoupleSpace`
  model and stores the returned `spaceId` alongside it. Low-risk to switch to the
  model UUID if the developer prefers a single identifier.
- **[Redundant `coupleSpaceId` in payloads]** Left the existing `coupleSpaceId` fields
  on five models untouched even though the document path now carries space context.
  Reason: editing the models is not "thin"; the field is harmless. `MoodStatus` needs
  no change (it never had the field).
- **[Delete permission]** Allowed **either member** to delete any item, matching the
  CloudKit shared-zone behavior where both partners could modify the shared hierarchy.
  Tighten to author-only later if product wants it.
- **[Pair-code read openness]** Any signed-in user may `get` a `pairCodes/{code}` by
  ID (needed for the not-yet-member partner). Reason: codes hold only a space title +
  ID; a guessed code still cannot join because the **space** join rule is the real
  gate. Enumeration (`list`) is disabled. Score < 7, no takeover risk.
- **[Expiry enforced client-side]** Kept CloudKit's client-side 48h expiry check on
  redemption rather than encoding "now" comparisons into read rules. Reason: the
  join-authorization boundary (space rule) is what protects data; the code read is not
  sensitive.
- **[No Cloud Functions / background push in MVP]** Deferred all server-side push and
  cleanup to a Blaze follow-up, per R5's explicit allowance to rely on foreground
  listeners + existing local notifications for MVP. This is the only capability with
  reduced parity vs. CloudKit's silent zone-subscription push, and it is flagged
  clearly for the service planner.
```
