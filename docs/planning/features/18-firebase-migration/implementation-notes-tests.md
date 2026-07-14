# Implementation Notes — tests

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Date**: 2026-07-14
**Agent**: @test-engineer

## Summary
Three critical-path tests exercise the pure logic of the invite flow through
`FirebaseService`'s public API — no network, no mocking frameworks. All pass on the
iPhone 17 simulator (`TEST SUCCEEDED`, 0.008s each). Written in Swift Testing (`import
Testing`) to match the existing `TweliTests.swift`, not XCTest.

## Files Created / Modified
- `TweliTests/TweliTests.swift` — replaced the scaffold `example()` test with the 3 real tests below (exclusive-ownership path).

## The 3 Tests (suite `18-firebase-migration invite flow`, `@MainActor`)
1. **`pairCodeNormalizationContract`** (happy) — `normalizePairCode` collapses both
   `"7gk-4pb"` and `"7GK 4PB"` to canonical `"7GK4PB"` (6 chars); `codeAlphabet`
   excludes the ambiguous glyphs 0/O/1/I/L, is all uppercase/digits, and is a superset
   of any normalized code. (`makeCode` is `private static`, so per the task the
   generation contract is asserted via the alphabet + normalization, not by calling it.)
2. **`pairCodeErrorCopyContract`** (error 1) — every `PairCodeError` case
   (`notFound / expired / badShareURL / spaceFull / network`) has the exact user-facing
   copy from `FirebaseService.swift`, asserted via `localizedDescription` (the string
   the join/confirm views actually render — the UX contract downstream depends on).
3. **`thinPayloadRoundTrip`** (error 2) — each of the six Codable item models
   (`ReminderItem`, `CountdownItem`, `OpenWhenLetter`, `VirtualDateItem`, `MoodStatus`,
   `MissingYouPing`) survives the exact `JSONEncoder → utf8 String → JSONDecoder` path
   that `FirebaseService.save` uses for the `payload` field, with `id` and a key field
   intact (thin-payload invariant, DECISIONS.md §4).

## Run Command
```bash
xcodebuild test -project Tweli.xcodeproj -scheme Tweli \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TweliTests 2>&1 | tail -30
```
Result: `** TEST SUCCEEDED **` — 3/3 passed.

## Assumptions (auto-mode defaults; no AskUserQuestion)
- **[Framework]** Used Swift Testing (`import Testing` / `@Test` / `#expect`), not XCTest
  as the task text suggested. Reason: the existing `TweliTests.swift` is Swift Testing;
  the agent rule "match existing test patterns" and the task's own "check the existing
  file style" both point here. Module import is `@testable import Tweli` (confirmed).
- **[Simulator]** Targeted `iPhone 17` — the task's `iPhone 16` is absent from this
  machine (`xcrun simctl list devices available` shows iPhone 17 / 17 Pro / Air / 16e).
- **[MainActor isolation]** Marked the whole suite `@MainActor` because `normalizePairCode`
  / `codeAlphabet` are static members of the `@MainActor` `FirebaseService` and inherit
  its isolation; the model round-trip needs no isolation but is harmless under it.
- **[No live-Firebase E2E]** Per the orchestrator's pre-approved deviation, no XCTest
  against live Firestore (flaky/credentialed). The tests hit the deterministic pure
  logic behind the same boundary instead.

## Notes for Downstream Agents
- No app-code bugs found; the copy strings and Codable conformances all match the spec.
- These tests are network-free and deterministic — safe to run in the verification gate
  (TEST-2) with no simulator auth/Firebase setup.
- `makeCode()` and the network methods (`createSpace`, `redeemPairCode`, `joinSpace`)
  are not unit-tested here — they require live Firestore or a mock SDK, both out of MVP
  scope; their pure inputs (`normalizePairCode`, `codeAlphabet`, `PairCodeError`) are.
