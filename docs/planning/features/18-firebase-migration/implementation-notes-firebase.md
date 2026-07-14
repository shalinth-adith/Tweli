# Implementation Notes — firebase

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Date**: 2026-07-12
**Agent**: @firebase-developer

## Summary
Created the repo-side Firebase artifacts for the CloudKit→Firestore migration: the
complete `firestore.rules` (transcribed verbatim from database.md §3), an empty
`firestore.indexes.json` (§4 — no composite indexes needed at MVP), and the CLI config
(`firebase.json` + `.firebaserc` → project `tweli-9a99e`). Rules compile clean against
the live project via `firebase deploy --dry-run`. No Swift, no Cloud Functions (Spark
plan). Not deployed — the user deploys (instructions below).

## Files Created / Modified
- `firestore.rules` — full ruleset: member-only space access, atomic 1→2 join guard, member-edit path, six-subcollection whitelist, `validItem` (authorUid == auth.uid), space delete forbidden, pair-code get/create/creator-write with list disabled.
- `firestore.indexes.json` — `{ "indexes": [], "fieldOverrides": [] }` per §4.
- `firebase.json` — `firestore` section only (rules + indexes paths); no hosting/functions.
- `.firebaserc` — default project `tweli-9a99e`.

## Validation
- `firebase deploy --only firestore:rules --dry-run --project tweli-9a99e` → **compiled successfully, dry run complete**.
- Two benign warnings: `Unused variable: spaceId` at the `isAtomicJoin`/`isMemberEdit` definitions. They take a `spaceId` param for call-site symmetry with `isMember(spaceId)` but operate on `resource`/`request.resource`. Kept verbatim to match authoritative §3; safe to ignore (warnings, not errors).

## Deploy Instructions (user runs — DO NOT auto-deploy)
Two equivalent paths. CLI is authoritative; console-paste is the fallback.

**A. Firebase CLI (from repo root `/Users/shalinthadithyan/Desktop/master/Tweli`):**
```bash
firebase login                 # if not already authenticated
firebase deploy --only firestore:rules,firestore:indexes --project tweli-9a99e
```
Deploys both `firestore.rules` and `firestore.indexes.json`. Re-run after any rules edit.

**B. Console paste (no CLI):**
1. Firebase Console → project `tweli-9a99e` → Firestore Database → **Rules** tab.
2. Replace the editor contents with the full text of `firestore.rules`, click **Publish**.
3. Indexes are empty, so nothing to paste on the **Indexes** tab.

**Verify after deploy:** Rules tab shows the new ruleset with a fresh publish timestamp;
Firestore Rules Playground can spot-check (e.g. a non-member `get` on a space → denied).

## Assumptions (auto-mode defaults; no AskUserQuestion)
- **[Rules verbatim]** Transcribed §3 exactly rather than "fixing" the two unused-param warnings. Reason: database.md §3 is the authoritative, immutable spec; the params are cosmetic and the warnings are non-blocking.
- **[fcmTokens writes]** DECISIONS.md §5 ships an `fcmTokens` map on the space doc now. §3 has no dedicated `fcmTokens` clause — a member writing their own token is already permitted by the `isMemberEdit` path (memberUids/ownerUid/createdAt stay frozen, title stays valid, other fields like `fcmTokens` are unconstrained). No rule change made; the member-edit shape covers it. If product later wants to forbid a member overwriting the partner's token entry, tighten `isMemberEdit` to diff `fcmTokens.keys()`.
- **[No indexes]** Empty manifest per §4: every query is single-collection single-field-ordered (Firestore auto-indexes those) or a direct `getDocument` by ID. Add composite indexes reactively from the console link if a future multi-field query appears.
- **[Dry-run only]** Ran `--dry-run` (validation, reached the live project since the Firestore API is enabled and the user is authenticated) but did NOT publish. Deploy is the user's action per task scope.

## Deferred (with blocker)
- **Cloud Functions / background push** — Blaze-plan only (DECISIONS.md §3, database.md §6/§7). `onItemWritten` FCM fan-out and `reapExpiredCodes` cleanup are out of scope for MVP; foreground snapshot listeners + existing local notifications cover the MVP path.
- **`storage.rules`** — not created; the app stores text-only JSON payloads, no Firebase Storage usage in this feature.

## Notes for Downstream Agents (Swift / FirebaseService)
- **Access matrix**: space `get/list` → members only (`request.auth.uid in resource.data.memberUids`). Item subcollections `read/create/update/delete` → members only, and writes must set `authorUid == Auth.auth().currentUser.uid` and `schemaVersion` as an int, else rejected. `pairCodes` `get` → any signed-in user; `create` → self as `createdBy`; `update/delete` → creator only; `list` → always denied.
- **Join must be a client transaction**: read `spaces/{spaceId}`, verify `memberUids.size() == 1`, then `arrayUnion(uid)` + add own `memberNames[uid]`. The rule only admits an exact 1→2 transition with the original member + owner + title + createdAt unchanged — a racing second joiner sees size 2 and is rejected.
- **No composite indexes exist** — if you add a `where(...).order(by:...)` across a subcollection, the runtime error carries a console link; add the index to `firestore.indexes.json` then and redeploy.
- **Project id** for the SDK / `GoogleService-Info.plist` is `tweli-9a99e`.
