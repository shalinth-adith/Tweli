# Validation Report — 18 Firebase Migration (CloudKit → Firebase)

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Validator**: @feature-plan-validator
**Date**: 2026-07-11
**Scope**: read-only review of requirements.md, database.md, api-endpoints.md,
ui-components.md, FEATURE_INDEX.md, tasks.md, feature-status.json.

## Final status: PASS WITH WARNINGS

The plan is coherent and implementable. All seven requirements trace to spec
sections and tasks; the security rules cover every documented access path; the
pair-code semantics, `RType` plurals, and the `PairInvite`/`PendingInvite` reshape
are consistent across specs; and `feature-status.json` matches `tasks.md` exactly.

Five cross-spec inconsistencies remain. None blocks the start of implementation
because the **implementation-driving artifacts** (`tasks.md` + `database.md`
security rules + `FEATURE_INDEX.md`) are mutually consistent, and each divergence has
an obvious, already-documented correct resolution. However, two of them (W1 leave
semantics, W2 space-full error case) would cause **runtime failures** if built
exactly as the UI spec / tasks currently read, so they should be reconciled before
or during the affected tasks (UI-3, UI-4). W3–W5 are documentation-consistency fixes
in `api-endpoints.md` / `database.md` prose that an implementer following `tasks.md`
would not hit, but which mislead anyone reading those specs in isolation.

---

## 1. Document inventory

| Document | Present | Non-empty | Structure | Notes |
|---|---|---|---|---|
| requirements.md | yes | yes (≈6 KB) | R1–R7 + constraints + out-of-scope | Clear contract |
| database.md | yes | yes (≈28 KB) | §1–§9 + Assumptions | Complete `firestore.rules`, quota, offline |
| api-endpoints.md | yes | yes (≈30 KB) | Identity model, full surface, auth, invite, sync, FCM, SPM, prereqs, migration impact | Swift service layer (no REST backend — correct) |
| ui-components.md | yes | yes (≈16 KB) | §1–§7 + Assumptions | State/copy/plumbing only; no redesign |
| FEATURE_INDEX.md | yes | yes (≈24 KB) | Inventory, stats, cross-cutting decisions, reading order, prereqs, quick ref | Accurate; uses `memberNames` (matches DB/tasks) |
| tasks.md | yes | yes | 40 tasks, 11 phases, summary + critical path | IMMUTABLE header present |
| feature-status.json | yes | yes | 40 IDs, all `false` | Matches tasks.md exactly |

No placeholder text (`[TODO]`, `[FILL THIS]`) found in any spec.

---

## 2. Requirement traceability (R1–R7)

Every requirement traces to at least one spec section and one task. All covered.

| Req | Spec coverage | Tasks | Verdict |
|---|---|---|---|
| R1 — Firebase Auth (SIWA nonce) + keep DEBUG bypass | api "Sign in with Apple → Firebase Auth"; db §9(4) | AUTH-1, AUTH-2, AUTH-3, FS-2, SETUP-3 | ✅ |
| R2 — Firestore data model + security rules | db §2, §3 | FS-1, INV-1, SETUP-5, SYNC-1 | ✅ |
| R3 — invite flow parity | db §2.3; api "Space creation…"; ui §1–§3 | INV-1..5, UI-1..3, SETUP-8 | ✅ |
| R4 — sync parity (listeners, deletions, offline) | db §5; api "Snapshot-listener sync" | SYNC-1..4, TEST-4 | ✅ |
| R5 — FCM push (Blaze deferral accepted) | db §6/§7; api "FCM integration" | PUSH-1, SETUP-6 | ✅ (deferral is an accepted decision) |
| R6 — cutover, retire CloudKit | api "Caller migration impact" | CLEAN-1..3, TEST-5 | ✅ |
| R7 — widget local-only, no Firebase | api "SPM dependencies" (widget links none) | SPM-1, WIDGET-1, TEST-6 | ✅ |

Team-lead-requested surface checks: user console tasks (SETUP-1..8) ✅; widget
check (WIDGET-1, TEST-6) ✅; CloudKit cleanup (CLEAN-1..3, TEST-5) ✅;
two-simulator verification flow (TEST-3, TEST-4) ✅.

---

## 3. firestore.rules coverage of documented access paths

| Access path | Rule | Covered |
|---|---|---|
| Member-only space read | `allow get, list: … uid in resource.data.memberUids` | ✅ |
| Max-2 join atomicity, no takeover | `isAtomicJoin` (count 1→2, caller is new member, owner/existing member frozen) | ✅ |
| Pair-code redemption without membership | `pairCodes` `allow get: if isSignedIn()` | ✅ |
| Pair-code list/enumeration disabled | `pairCodes` `allow list: if false` | ✅ |
| Pair-code writable only by creator | `create` (`createdBy == uid`), `update/delete` (`resource.data.createdBy == uid`) | ✅ |
| Item subcollections member-only, six types only | `isKnownItemType()` + `isMember()` + `validItem()` | ✅ |
| Space never client-deletable | `allow delete: if false` | ✅ |
| FCM token write (`fcmTokens[uid]` on space doc) | permitted by `isMemberEdit` (title/memberUids/ownerUid/createdAt frozen; extra field allowed) | ✅ (field-on-space form only — see W5) |

The rules are internally sound. `spaceData()`/`get()` billing cost is acknowledged
in db §3/§6 and is negligible at two-user scale.

---

## 4. Consistency checks explicitly requested

| Check | Result |
|---|---|
| Collection names / RType plurals | ✅ Consistent everywhere: `reminders`, `countdowns`, `letters`, `virtualDates`, `moods`, `pings` (db §2, api `RType`, rules `isKnownItemType`, tasks, FEATURE_INDEX). |
| Pair-code alphabet | ✅ `23456789ABCDEFGHJKMNPQRSTUVWXYZ` in all specs; correctly excludes `0/O/1/I/L`. |
| Pair-code 48h expiry | ✅ Consistent; enforced client-side on redemption in all specs. |
| Pair-code normalization | ✅ Uppercase + strip non-alphabet; identical description in db §2.3 and api. |
| PairInvite / PendingInvite reshape | ✅ Consistent: `PairInvite {spaceId, spaceTitle, inviterName}`; `PendingInvite` rewrapped, load-bearing fallbacks (`"your shared space"`, `"Your partner"`) preserved (INV-3, INV-5, ui §3). |
| Space-full outcome | ⚠️ Concept consistent, but the concrete error case is under-specified — see **W2**. |
| Space document schema (memberNames) | ⚠️ db/tasks/FEATURE_INDEX use `memberNames` map; api-endpoints.md prose uses scalar `ownerName`/`participantUid`/`participantName` — see **W3**. |

---

## 5. tasks.md ↔ feature-status.json integrity

- **40 tasks** in `tasks.md`; **40 IDs** in `feature-status.json`. Sets are
  **identical** (SETUP-1..8, SPM-1..2, FS-1..2, AUTH-1..3, INV-1..5, SYNC-1..4,
  PUSH-1, UI-1..5, WIDGET-1, CLEAN-1..3, TEST-1..6).
- All 40 values are `false` (no partially-marked state). ✅
- `tasks.md` carries the IMMUTABLE header; descriptions are intact; the summary
  table and critical path are internally consistent (11 phases, 40 total). ✅
- Dependency ordering is acyclic and sensible (console → SPM → service skeleton →
  auth → invite → sync → push → UI → cleanup → verification). ✅

---

## 6. Findings (warnings)

### W1 — "Leave / disconnect" contradicts the security rules (fix before UI-4)
`ui-components.md` §4 and **tasks UI-4** say `disconnect()` should remove
`currentUid` from `memberUids`, or delete the space if the leaver is the sole member
("**leave removes membership**"). The deployed rules from **database.md** forbid
**both**: `allow delete: if false` (db §3, ~line 215) makes the space
un-deletable from the client, and `isMemberEdit` freezes membership
(`request.resource.data.memberUids == resource.data.memberUids`, ~line 240);
`isAtomicJoin` only permits a 1→2 growth. There is no rule branch that lets a member
remove their own uid. So UI-4's acceptance ("leave removes membership") would hit
**permission-denied at runtime**. Meanwhile database.md §8 and api-endpoints.md
`reset()` define leave as **clearing local state only** ("does not delete the remote
space; delete is disabled in rules").
- **Refs**: ui-components.md §4; tasks.md UI-4; database.md §3 (`allow delete: if
  false`, `isMemberEdit`), §8; api-endpoints.md `reset()`.
- **Recommended resolution**: pick one and align the specs — either (a) make leave
  **local-only** (align UI-4 with `reset()` / database §8), the simplest MVP path; or
  (b) add a rule branch permitting a member to remove **only their own** uid (and
  never delete the space) and update the transaction accordingly.

### W2 — No dedicated error case for "space full", but UI must show distinct copy (fix before UI-3)
`PairCodeError` has four cases: `notFound / expired / badShareURL / network`
(api-endpoints.md; **INV-3**). ui-components.md §5 and **tasks UI-3** require a *new,
distinct* copy for the full-space case ("This space already has two people. Ask your
partner to send you a fresh invite."), separate from the `badShareURL` copy ("This
invite looks broken…"). api-endpoints.md suggests surfacing space-full as
"`badShareURL`-adjacent", and **INV-4** says only "throw a friendly space-is-full
error" without naming a concrete case. If `joinSpace` throws
`PairCodeError.badShareURL`, `JoinConfirmView` will show the wrong ("invite looks
broken") copy; there is no enum case the UI can branch on to reach the new copy.
- **Refs**: api-endpoints.md error taxonomy + join section; ui-components.md §5;
  tasks.md INV-4, UI-3.
- **Recommended resolution**: define a dedicated error (e.g. add
  `PairCodeError.spaceFull`, or a separate `JoinError.spaceFull`) so UI-3 can branch
  to the space-full copy deterministically. A one-line spec/enum addition.

### W3 — api-endpoints.md space-document schema diverges from db/tasks/FEATURE_INDEX (doc fix)
The **authoritative** artifacts model the space document with a `memberNames`
map<uid,displayName> (database.md §2.1; tasks **INV-1** writes
`memberNames = { ownerUid: displayName }`; **INV-4** writes
`memberNames[currentUid]`; FEATURE_INDEX quick-ref lists `memberNames`). But
**api-endpoints.md** prose writes scalar fields instead: `createSpace` writes
`ownerName` (not `memberNames`), and `joinSpace` sets `participantUid` /
`participantName`. The security rules are written for the `memberNames` form — the
`create` rule requires `memberNames.keys().hasOnly([auth.uid])`, and `isAtomicJoin`
requires `memberNames[joiner] is string`. An implementer following api-endpoints.md
verbatim would produce **rule-violating writes** (permission-denied on both create
and join).
- **Refs**: api-endpoints.md (createSpace / joinSpace sections); database.md §2.1 +
  §3 (`create`, `isAtomicJoin`); tasks.md INV-1, INV-4; FEATURE_INDEX quick ref.
- **Recommended resolution**: reconcile api-endpoints.md to the `memberNames` map
  (the DB rules + tasks are correct and should stand). `tasks.md` already drives the
  implementer correctly, so this is a doc-consistency fix, but api-endpoints.md is the
  `FirebaseService` build spec and should not read as rule-violating.

### W4 — database.md `authorUid` description conflates the two identities (doc fix)
database.md §2.2 describes `authorUid` as "Firebase UID of the writer (**denormalized
from `payload.createdBy`/`sentBy`/`userId`**)", and the per-type table lists the
`authorUid` source as `createdBy` / `userId` / `sentBy`. Those payload fields are
**App-profile UUIDs**, not Firebase UIDs (the dual-identity model states the Firebase
UID never enters a payload). The `validItem()` rule requires `authorUid ==
request.auth.uid` (the Firebase UID). tasks **SYNC-1** and api-endpoints.md correctly
set `authorUid: currentUid`. Taken literally, denormalizing `authorUid` from
`payload.createdBy` would make **every item write fail** the rule.
- **Refs**: database.md §2.2 (field table + per-type table), §3 `validItem`;
  api-endpoints.md item CRUD; tasks.md SYNC-1.
- **Recommended resolution**: correct database.md's wording to "`authorUid` =
  `currentUid` (the writer's Firebase UID)"; drop the "denormalized from payload…"
  phrasing and the per-type `authorUid` source column.

### W5 — FCM token storage: field-name and shape drift (minor)
tasks **PUSH-1** and api-endpoints.md store the token as a `fcmTokens[uid]` map on the
space doc; database.md §7 (deferred Blaze note) calls the same thing `memberTokens`.
Separately, api-endpoints.md offers an alternative `spaces/{spaceId}/members/{uid}`
subcollection — but that path would be **blocked** by the item-subcollection rule
(`isKnownItemType` rejects any subcollection name outside the six item types), so the
field-on-space form (which tasks picks) is the only rule-compatible option.
- **Refs**: tasks.md PUSH-1; api-endpoints.md FCM section; database.md §7.
- **Recommended resolution**: standardize on `fcmTokens` (map on the space doc) across
  specs and remove the `members` subcollection alternative from api-endpoints.md.

### Minor observation (not a warning)
TEST-3's two-simulator path offers "one Apple + one anonymous via the documented
`devSignInWithRealSync` opt-in", but no implementation task builds
`devSignInWithRealSync()` — FS-2 implements only the offline `devSignIn()`. This is
harmless because TEST-3 also lists the two-real-Apple-IDs path (needs no extra code);
just be aware the anonymous opt-in would require a small unplanned addition if chosen.

---

## 7. Implementation readiness

Ready to implement. The critical path (SETUP-1 → SPM-1 → FS-1 → AUTH → INV → SYNC →
UI → CLEAN → TEST) is well-ordered, console/user-owned prerequisites are clearly
separated and gate only runtime verification, and the DEBUG offline bypass +
placeholder-safety posture are respected. Resolve W1 and W2 before implementing UI-4
and UI-3 respectively (both are one-line/one-branch fixes with the correct answer
already implied by the other specs); apply W3–W5 as doc-consistency cleanups so the
`FirebaseService` build spec and the schema doc stop reading as rule-violating.

**Status: PASS WITH WARNINGS.**

---

## Resolutions (2026-07-12, orchestrator)

All five warnings were resolved by spec amendments immediately after validation:

- **W1** — ui-components.md §4: `disconnect()` re-specified as local-only (detach listeners, clear local state via `FirebaseService.reset()`); no remote member removal or space delete, matching the rules and database.md §8.
- **W2** — api-endpoints.md: added `PairCodeError.spaceFull` (enum, `joinSpace` throw site, and error-taxonomy row with the ui-components copy "This space already has two people…").
- **W3** — api-endpoints.md: create/join/space-doc-listener sections rewritten to use the `memberNames` map exclusively; scalar `ownerName`/`participantUid`/`participantName` fields removed.
- **W4** — database.md §2.2: `authorUid` documented as always the writer's Firebase UID (`Auth.auth().currentUser.uid`), never derived from payload app-UUID fields; per-type table column relabeled as informational.
- **W5** — api-endpoints.md: FCM token storage standardized on the `fcmTokens` map on the space doc; `members/{uid}` subcollection alternative removed.

Effective status: **PASS** (no open warnings).
