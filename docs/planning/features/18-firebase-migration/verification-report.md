# MVP Verification Report

**Feature**: `18-firebase-migration` (CloudKit → Firebase/Firestore cutover)
**Date**: 2026-07-14
**Agent**: @mvp-quality-gate
**Mode**: MVP (`mvp_mode: true`, `batch_verify_mode` not set → per-feature auth-bypass runs)
**Platform**: iOS-only (SwiftUI, direct Firestore client — no web/server/RLS/auth-middleware layer)
**Status**: PASSED WITH WARNINGS

## Summary

The Firebase migration builds green, all 3 critical-path tests pass, and the Debug
`#if DEBUG` auth-bypass lands the app directly on the authenticated main shell on an
iPhone 17 simulator. The CloudKit removal is verified: zero `CK*` symbols or
`import CloudKit` remain in code (only doc-comment mentions, which the gate permits).
Firebase initialized cleanly at runtime (FirebaseMessaging 11.15.0 came up, no
config error, `GoogleService-Info.plist` read successfully). The two live-Firestore
E2E flows (invite propagation, deletion propagation) are deferred to manual testing
because Debug builds short-circuit Firestore via the dev bypass — they require real
Sign in with Apple sessions across two devices (documented in
`implementation-notes-swiftui.md`).

One environment workaround was required: the repo lives under an iCloud-synced
Desktop folder, which stamps `com.apple.FinderInfo` xattrs on build products and
makes `codesign` reject SwiftPM resource bundles ("resource fork ... detritus not
allowed"). Building into a non-synced DerivedData path resolves it. This is an
environment/tooling issue, NOT a code defect.

## Critical Checks (BLOCKING)

| Check | Status | Details |
|-------|--------|---------|
| Build (TEST-1) | PASS | `** BUILD SUCCEEDED **` — app + `TweliWidgetExtension` targets, Debug, iPhone 17 sim. Required non-synced DerivedData path (see Environment Note). |
| Type Safety | PASS | Compile-time via build (Swift); 0 errors. |
| RLS Policies | N/A | Firestore uses security rules, not RLS. Rules authored + deployed to `tweli-9a99e` (dry-run compiled clean; user deployed per firebase notes). |
| Auth Middleware | N/A | iOS-only, direct Firestore client — no backend routes. |
| Critical Tests (TweliTests) | PASS | 3/3 passed on iPhone 17: `pairCodeNormalizationContract`, `pairCodeErrorCopyContract`, `thinPayloadRoundTrip` (~0.007s each). `** TEST SUCCEEDED **`. |
| Auth-Bypass Flow (TEST-2) | PASS | Debug `#if DEBUG` mock session lands on authenticated main shell — "Open-When Letters" screen, full 5-tab bar (Home/Reminders/Dates/Moods/Letters), FAB, populated content. Not a crash/blank/sign-in wall. Screenshot: `verification-screenshots/18-firebase-migration-auth-bypass.png`. |
| CloudKit Removal (TEST-5) | PASS | grep for `import CloudKit\|CKShare\|CKRecord\|CKError\|CKContainer` and broad `\bCK[A-Z]` sweep → 5 hits, all comment-only (doc comments + one TODO). Zero code symbols. Gate explicitly permits comment mentions. |
| Firebase Runtime Init | PASS | Console shows `FIRMessaging ... 11.15.0` proxy enabled (INFO). No `FirebaseApp.configure()` failure, no missing-`GoogleService-Info` error, no crash. |
| Placeholder Safety | PASS | Dev-placeholder prefix, lorem-ipsum, fake-name, and dev-marker greps → zero hits in `Tweli/` outside debug/test/preview. |

## Optional Checks (WARN only)

| Check | Status | Details |
|-------|--------|---------|
| Visual Smoke | PASS | 3 screenshots captured; main shell renders cleanly — strong contrast (white-on-dark), safe-area-respecting tab bar, no encoding artifacts / overflow / blank sections. |
| Widget Firebase-independence (TEST-6) | PASS | `TweliWidget/` has zero Firebase imports; `WidgetDataService.swift` imports only Foundation/Combine/WidgetKit. Widget extension built as part of TEST-1. |
| Console Noise | WARN | `CHHapticPattern` / `hapticpatternlibrary.plist` errors are an iOS Simulator-only limitation (no haptics on sim), not an app bug. Ignorable. |
| Test Coverage | WARN | 3 pure-logic tests only. Network methods (`createSpace`/`redeemPairCode`/`joinSpace`) untested — need live Firestore/mock SDK. Expected for MVP. |
| E2E Tests | WARN | No live-Firestore E2E (flaky/credentialed). Expected for MVP. |

## Deferred to Manual Testing

| Task | Reason |
|------|--------|
| TEST-3 (two-simulator invite E2E) | Debug builds short-circuit Firestore via the dev bypass (`dev-` uid + `isDevOrOffline` guard). Needs two real Sign in with Apple sessions across two devices, or temporary removal of the dev short-circuit. Per `implementation-notes-swiftui.md` Notes. |
| TEST-4 (deletion propagation) | Same blocker — requires two authenticated live-Firestore sessions to observe cross-device snapshot removal. |

## Commands Used

```
# Simulator discovery
xcrun simctl list devices available

# TEST-1 build (DD = non-synced scratchpad path to avoid iCloud FinderInfo codesign issue)
xcodebuild -project Tweli.xcodeproj -scheme Tweli -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath "$DD" build

# Tests
xcodebuild test -project Tweli.xcodeproj -scheme Tweli -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath "$DD" \
  -only-testing:TweliTests

# TEST-5 CloudKit gate
grep -rn "import CloudKit\|CKShare\|CKRecord\|CKError\|CKContainer" Tweli/ TweliWidget/ --include="*.swift"
grep -rnE "\bCK[A-Z][A-Za-z]+" Tweli/ TweliWidget/ --include="*.swift"

# TEST-2 auth-bypass launch
xcrun simctl boot F0DC9C2F-F559-431D-A2AC-C5DDE6E2B2ED   # iPhone 17, iOS 26.0
xcrun simctl install booted "$DD/Build/Products/Debug-iphonesimulator/Tweli.app"
xcrun simctl launch booted me.adithyan.shalinth.Tweli
xcrun simctl io booted screenshot <path>

# Console
xcrun simctl spawn booted log show --last 3m --predicate 'processImagePath contains "Tweli"'
```

## Environment Note (non-code)

`codesign` failed on the SwiftPM `abseil_abslWrapper.bundle` with "resource fork,
Finder information, or similar detritus not allowed". Root cause: the repo path
(`~/Desktop/master/Tweli`) is under iCloud Desktop & Documents sync, which stamps
`com.apple.FinderInfo` + `com.apple.fileprovider.fpfs#P` on freshly-created build
products. Fix: build into DerivedData outside the synced tree
(`-derivedDataPath <non-synced path>`). No source change needed. Recommend adding a
non-synced DerivedData location (or moving the repo out of iCloud-synced Desktop) to
avoid this on every clean build.

## Screenshots

- `verification-screenshots/18-firebase-migration-auth-bypass.png` — authenticated main shell (Open-When Letters, full tab bar)
- `verification-screenshots/18-firebase-migration-loaded.png` — stable loaded frame
- `verification-screenshots/18-firebase-migration-feature.png` — second stable frame

## Decision

**Status: PASSED WITH WARNINGS** — MVP meets essential quality standards:

- Build passes (deployable)
- Core tests pass (3/3)
- Auth-bypass verified end-to-end on simulator
- CloudKit fully removed (zero code symbols)
- Firebase initializes clean at runtime

Expected MVP gaps (acceptable): live-Firestore E2E deferred to manual, low unit
coverage on network methods.

**Recommendation: DEPLOY for user testing.** Before scaling: run the two deferred
manual E2E flows (invite + deletion propagation) on two real devices with distinct
Apple IDs.

## Next Steps

1. Deploy for user testing.
2. Manually run TEST-3 / TEST-4 on two devices with real Sign in with Apple.
3. MVP graduation: add mock-SDK tests for `createSpace`/`redeemPairCode`/`joinSpace`,
   run `@code-reviewer` + full `@verification-agent`.
4. Fix the iCloud-sync DerivedData codesign friction (move repo or pin DerivedData).
