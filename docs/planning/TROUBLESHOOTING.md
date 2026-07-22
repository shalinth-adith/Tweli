# Troubleshooting Log

Failure modes, their signals, and prevention rules. Append-only.

## 2026-07-22 — Auth/Rules: Partner could not join a space (PERMISSION_DENIED on join transaction)

**Symptom**: Second user stuck on the Welcome screen; entering a valid invite code showed the confirm sheet, but tapping Join failed with the generic "Couldn't check the code right now" network error. Join never succeeded for anyone.

**Root Cause**: `FirebaseService.joinSpace` runs a Firestore transaction that READS `spaces/{spaceId}` before its atomic update. `firestore.rules` only allowed `get` on a space for existing members — and the joiner is by definition not a member yet. Firestore evaluates rules per-operation inside transactions, so the read was denied and the whole transaction aborted with PERMISSION_DENIED. The rules had a correct `isAtomicJoin` UPDATE path but never granted the READ the client needs to reach it. Compounding: the rules file on disk had drifted from the deployed ruleset (the `locations` allowlist change was never deployed).

**Fix**:
1. `firestore.rules` — split `get`/`list`: a signed-in non-member may `get` a space that still has an open seat (`memberUids.size() < 2`). Exposure matches what the pair code already reveals. Full spaces stay member-only.
2. `FirebaseService.joinSpace` — map `FirestoreErrorCode.permissionDenied` to `.spaceFull` (after the fix, a denied join read means both seats are taken), instead of the misleading `.network` copy.
3. Deployed via `firebase deploy --only firestore:rules` to `tweli-9a99e`.

**Prevention**:
- Any client code that reads inside a Firestore transaction needs a matching `get` rule for the *pre-state* caller (e.g. the not-yet-member), not just an update rule for the write.
- Never leave `firestore.rules` undeployed at the end of a session — rules drift makes local reasoning about live behavior wrong. Deploy in the same session as the edit.
- Flows verified "by inspection" that require two real accounts (invite E2E) must be flagged as unverified until actually run on two devices.

**Files Changed**: `firestore.rules`, `Tweli/Services/FirebaseService.swift`
