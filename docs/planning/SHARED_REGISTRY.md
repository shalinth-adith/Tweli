# SHARED_REGISTRY.md — shared types, components, utilities

Seeded 2026-07-12 during 18-firebase-migration. Append-only; reuse before you create.

## Services (singletons owned by AppViewModel)
- `FirebaseService` → `Tweli/Services/FirebaseService.swift` — sole backend boundary (Firestore/Auth/FCM). Replaces `CloudKitService` (retired). Typed wrappers: `saveReminder/deleteReminder/saveCountdown/deleteCountdown/saveLetter/saveVirtualDate/saveMood/sendPing`, invite ops `createSpace/publishPairCode/redeemPairCode/joinSpace`, sync `startListening/stopListening`, `reset()`.
- `AuthService` → `Tweli/Services/AuthService.swift` — Sign in with Apple + Firebase Auth session; `#if DEBUG` mock session bypass.

## Shared types
- `PairInvite` → defined with FirebaseService — `{spaceId, spaceTitle, inviterName}`; feeds `PendingInvite` for the join-confirm sheet.
- `PairCodeError` → FirebaseService — `notFound/expired/badShareURL/spaceFull/network` with fixed copy.
- `RemoteChanges` → FirebaseService — `payloadsByType: [String: [Data]]`, `deletedIDs: [UUID]`, `partnerJoinedName: String?`; consumed unchanged by `AppViewModel.mergeRemote`.
- Item models (all Codable, `id: UUID`) → `Tweli/Models/` — `ReminderItem, CountdownItem, OpenWhenLetter, VirtualDateItem, MoodStatus, MissingYouPing, CoupleSpace, UserProfile, PendingInvite`.

## Constants
- Pair-code alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ` + `normalizePairCode` — static on FirebaseService; the ONLY implementation (never duplicate).
- Firestore collection names — plural lowercase per DECISIONS.md §4; use FirebaseService.RType constants, never string literals.
