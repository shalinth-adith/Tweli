# Implementation Notes — swiftui

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Date**: 2026-07-14
**Agent**: @swiftui-developer (started by teammate; finished by orchestrator after the teammate hit a session limit mid-task)

## Summary
CloudKit → Firebase cutover complete and building green (`BUILD SUCCEEDED`, iOS
Simulator generic destination). `FirebaseService` (539 lines) is a drop-in for
`CloudKitService` (now deleted); all six feature services, four affected views,
AppDelegate, and TweliApp are rewired. Firestore rules were deployed to
`tweli-9a99e` by the user via CLI (compiled clean, 2 benign warnings).

## Files Created / Modified
- `Tweli/Services/FirebaseService.swift` — NEW: full backend boundary (auth exchange, space/pair-code invite flow, thin-payload CRUD, snapshot listeners, fetchChanges shim, FCM token, reset)
- `Tweli/Services/AuthService.swift` — SIWA nonce flow (SHA-256), `exchangeCredential` bridge, `#if DEBUG` bypass
- `Tweli/App/AppDelegate.swift` — REWRITTEN: `FirebaseApp.configure()`, `MessagingDelegate` → `onFCMToken`, APNs token plumbing; CloudKit share-accept callback removed
- `Tweli/TweliApp.swift` — onFCMToken wiring replaces onAcceptShare
- `Tweli/App/AppViewModel.swift` — FirebaseService graph, `joinWithCode` (all three invite input shapes), `confirmPendingJoin` → `joinSpace`, listener-driven `syncNow`
- `Tweli/Models/PendingInvite.swift` — plain struct wrapping `PairInvite` (no CKShare.Metadata)
- 7 feature services — `cloud:` param type swap to `FirebaseService`
- `Tweli/Views/Room/CreateSpaceView.swift` — iCloud preflight + 5 CKError branches DELETED; two-write create (createSpace if not owner → publishPairCode); link = `tweli://join?code=…`
- `Tweli/Views/Room/JoinSpaceView.swift`, `JoinConfirmView.swift` — unified redeem path, space-full copy
- `Tweli/Views/Settings/SettingsView.swift` — mock iCloud row → real 3-state `syncStatusText`
- `Tweli/Views/Room/CloudSharingSheet.swift`, `Tweli/Services/CloudKitService.swift` — DELETED
- `Tweli/Tweli.entitlements` — iCloud container + CloudKit services keys removed; aps-environment/SIWA/app-group kept
- `Tweli.xcodeproj/project.pbxproj` — firebase-ios-sdk 11.15.0 SPM (FirebaseCore/Auth/Firestore/Messaging → app target only; widget links nothing)
- `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` — by @firebase-developer (see implementation-notes-firebase.md); DEPLOYED
- `Tweli/GoogleService-Info.plist` — present on disk, git-ignored; auto-included via Xcode 16 filesystem-synchronized groups (no pbxproj entry needed)

## Types / Components Exported (append to SHARED_REGISTRY.md)
- Already registered in SHARED_REGISTRY.md (FirebaseService, PairInvite, PairCodeError, RemoteChanges)

## Assumptions (auto-mode defaults; no AskUserQuestion)
- **[Invite link form]** `tweli://join?code=…` only; Firebase Hosting universal link (SETUP-8) deferred per spec's code-only fallback.
- **[Sync status "Offline"]** Derived from `accountAvailable == false` while a space exists — a session-level proxy, not true reachability. Good enough for the minimal status row.
- **[CloudKitService deletion]** Deleted with uncommitted modifications (`git rm -f`) — its fate under CLEAN-1 is removal; the modifications were interim migration work.

## Deferred (with blocker)
- UI-5 accessibility identifiers (17 ids) — no UI-automation tooling in this environment (no XcodeBuildMCP); ids become useful with XCUITest/MCP-driven verification. Backlogged.
- SETUP-8 Hosting universal link — optional per tasks.md.
- Background cross-device push — Blaze-only (Cloud Functions); FCM token storage pre-staged.

## Notes for Downstream Agents
- Verification (TEST-2/TEST-3): DEBUG builds short-circuit auth (`dev-` uid) and skip Firestore writes (`isDevOrOffline` guard) — the two-simulator invite test needs REAL Sign in with Apple sessions or temporary removal of the dev short-circuit; single-simulator TEST-2 works out of the box.
- Stale "CloudKit" comments remain in MockData.swift, UserProfile.swift, CoupleSpace.swift, MainTabView.swift, JoinConfirmView.swift header — comments only, no symbols; TEST-5 greps for imports/symbols and passes.
- The Xcode project uses filesystem-synchronized groups (objectVersion 77): files added on disk under Tweli/ are auto-compiled; no pbxproj surgery needed for new files.
