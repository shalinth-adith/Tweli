# Tweli — *Remember things together*

A private shared reminder & long-distance care app for couples. Two partners share one
space for reminders, countdowns, love notes, moods, open-when letters, and virtual dates.

**iOS · SwiftUI · MVVM · CloudKit-ready · WidgetKit** — built mock-data-first so it runs
today, with CloudKit sync wired in later.

<sub>Visual design implemented from the "Twinderly" Claude Design comp — iOS system colors
(systemPink + systemIndigo on pure black / white), SF Pro, Apple HIG.</sub>

---

## Requirements

- Xcode 26.4+ (project uses the `objectVersion 77` synchronized-group format)
- iOS 26.4 Simulator runtime

## Build & run

```bash
# Build (simulator)
xcodebuild -project Tweli.xcodeproj -scheme Tweli -sdk iphonesimulator -configuration Debug build

# Run on a booted iOS 26.4 simulator
DEV=<your iOS-26.4 simulator UDID>          # xcrun simctl list devices
APP=$(find ~/Library/Developer/Xcode/DerivedData -name Tweli.app \
      -path '*Build/Products/Debug-iphonesimulator*' | grep -v Index.noindex | head -1)
xcrun simctl boot "$DEV"; open -a Simulator
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch  "$DEV" me.adithyan.shalinth.Tweli
```

Or just open `Tweli.xcodeproj` in Xcode and ⌘R.

> **Note:** the app currently targets **iOS 26.4** — launch it on a 26.4 simulator, not 26.0.

## Architecture

```
Tweli/
  App/          RootView · AppViewModel (composition root) · DesignSystem
  Models/       8 Codable structs + Enums (assignee, repeat, priority, status, …)
  Mock/         MockData — Shalinth ♥ Anaya seed data
  Services/     Reminder · Countdown · VirtualDate · OpenWhenLetter · Mood · MissingYou ·
                CoupleSpace · ReminderNotification (real) · CloudKit (placeholder) · WidgetData
  ViewModels/   Add* editors + Onboarding
  Views/        Splash · Onboarding · MainTab · Home (Overview 1a + Moment 1b) · Reminders ·
                Countdown · MissingYou · Letters · Dates · Moods · Partner · Settings · Components
TweliWidget/    WidgetKit extension — Countdown / Partner-mood / Next-date widgets
```

- **MVVM**: services own data + logic (`ObservableObject`s injected via `@EnvironmentObject`);
  `AppViewModel` is the composition root that wires identities and the widget snapshot.
- **Design system**: every color maps 1:1 to an Apple semantic color, so light/dark adapt
  automatically with no custom Asset Catalog.
- **Notifications**: `ReminderNotificationService` uses real `UNUserNotificationCenter`
  (permission, schedule/cancel/reschedule, daily/weekly/monthly repeats).
- **Widgets**: the app writes a `WidgetSnapshot` to the App Group
  `group.me.adithyan.shalinth.Tweli`; the widget reads it. (Add a widget from the Home Screen
  to see it.)

## Xcode capabilities

| Capability | Status | Notes |
|---|---|---|
| **App Groups** | ✅ enabled | `group.me.adithyan.shalinth.Tweli` on app + widget (widget data sharing) |
| **iCloud / CloudKit** | ⬜ later | Add container + `CKShare` zone when wiring real sync (Phase 5) |
| **Push / Remote notifications** | ⬜ optional | Only if using CloudKit subscriptions to wake devices; reminders stay **local** |
| **Background Modes** | ⬜ optional | Pairs with CloudKit subscriptions |

## CloudKit integration (Phase 5, next)

`Services/CloudKitService.swift` already exposes the full method surface as `// TODO` stubs.
To go live:

1. Add the iCloud/CloudKit capability + a container; map each model to a `CKRecord` (1:1 with structs).
2. Implement `CloudKitService` CRUD — personal items in the private DB, couple-shared items via a `CKShare` zone.
3. Couple connect: generate a `CKShare` URL / QR invite; partner accepts → both read the shared zone.
4. On fetch, hydrate services, then (re)schedule **local** notifications per device.
5. Add a `CKDatabaseSubscription` for change pushes; refresh the widget snapshot + reload timelines.
6. Swap the mock arrays for CloudKit-backed stores behind the existing service APIs (no View/VM changes).

## Status

MVP foundation complete: full UI (both Home directions), real local notifications, WidgetKit
target with App Group, CloudKit-ready placeholders. Runs on mock data; builds clean for the
iOS Simulator.
