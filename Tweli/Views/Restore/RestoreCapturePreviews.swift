//
//  RestoreCapturePreviews.swift
//  Tweli
//
//  DEBUG ONLY. The whole file is inside `#if DEBUG`, so none of it exists in any
//  distribution build.
//
//  This is the ONLY place in the app that holds stand-in figures, and it holds
//  them for one reason: comps K2–K5 are unreachable on a headless simulator.
//  Getting there for real needs a signed-in Apple account, a live paired space,
//  and an actual uninstall — and the simulator cannot inject the taps to walk
//  the flow either (it has no touch injection at all).
//
//  Every value is prefixed `PLACEHOLDER_` so it is greppable and unmistakably
//  fake, and the file is named `…Previews` so the repo's pre-ship placeholder
//  grep knows to skip it rather than fail the build. Nothing here is written to
//  UserDefaults, Firestore or the App Group.
//
//  Usage:
//    SIMCTL_CHILD_TWELI_RESTORE=k2 xcrun simctl launch <device> <bundle-id>
//    …with k2 | k3 | k4 | k5.
//

#if DEBUG

import Foundation

enum RestoreCapture {

    /// Applies the state named by `TWELI_RESTORE`, or does nothing.
    @MainActor
    static func applyIfNeeded(to app: AppViewModel) {
        // TWELI_AUTO_SIGNIN=<seconds> drives the LIVE sequence rather than
        // painting a frozen frame: paired with TWELI_REINSTALL=1 it walks
        // K1 → K2 → the outcome screen exactly as a real sign-in would. It is
        // the only way to check the state machine actually REACHES K2 on a
        // simulator, which cannot inject the tap on the Apple button.
        //
        // The delay matters. Signing in at t=0 fires while the splash is still
        // up, which is not what a real user does — they see the splash, then
        // K1, then tap. A delay past the splash reproduces the real ordering,
        // and it is how the "restore runs invisibly behind the splash" bug was
        // found in the first place.
        if let raw = ProcessInfo.processInfo.environment["TWELI_AUTO_SIGNIN"],
           !app.auth.isSignedIn {
            let delay = Double(raw) ?? 0
            Task { @MainActor in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !app.auth.isSignedIn else { return }
                app.auth.devSignIn()
            }
        }

        guard let key = ProcessInfo.processInfo.environment["TWELI_RESTORE"] else { return }
        switch key {
        case "k2": app.applyRestoreCaptureState(phase: .restoring, steps: steps)
        case "k3": app.applyRestoreCaptureState(phase: .rejoined, summary: summary)
        case "k4": app.applyRestoreCaptureState(phase: .cleanup, pendingCleanup: bothMissing)
        case "k5": app.applyRestoreCaptureState(phase: .pairGone, gone: gone)
        // M4 / ML4. `leftAt` is set to earlier the same day so the opening line
        // exercises its "this morning" branch rather than the fallback.
        case "m4":
            app.applyDepartureCaptureState(
                leftName: "PLACEHOLDER_Partner",
                leftAt: Calendar.current.date(bySettingHour: 9, minute: 20, second: 0,
                                              of: Date()))
        // M5 / ML5. Four days matches the comp, and lands in the "N days ago"
        // band rather than the "today"/"yesterday" special cases.
        case "m5":
            app.applyDepartureCaptureState(
                quietSince: Calendar.current.date(byAdding: .day, value: -4, to: Date()),
                quietPartnerName: "PLACEHOLDER_Partner")
        default: break
        }
    }

    // MARK: - Stand-in states

    /// `PLACEHOLDER_Partner` for verification captures, where an obviously fake
    /// name is the whole point — but the store listing photographs this same
    /// restore screen, and "Pair found — PLACEHOLDER_Partner" cannot ship. When
    /// TWELI_CAPTURE is set, borrow the store fixture's name instead.
    private static var standInName: String {
        ProcessInfo.processInfo.environment["TWELI_CAPTURE"] == "1"
            ? StoreCapture.partnerName
            : "PLACEHOLDER_Partner"
    }

    /// K2 mid-sequence: two rows settled, one working, one still to come. That
    /// combination is the interesting frame and also the hardest to catch live.
    private static var steps: [RestoreStep] { [
        RestoreStep(id: "account", title: "Account verified", state: .done),
        RestoreStep(id: "pair", title: "Pair found — \(standInName)",
                    detail: "214 days", state: .done),
        RestoreStep(id: "items", title: "Reminders & letters",
                    detail: "18 of 24", state: .running),
        RestoreStep(id: "mood", title: "Their mood & planned dates"),
    ] }

    /// K3 with all four stat rows populated, which is the layout worth checking.
    private static var summary: RestoreSummary { RestoreSummary(
        partnerName: standInName,
        pairedDays: 214,
        reminders: 24, openReminders: 6,
        letters: 6, sealedLetters: 1,
        partnerMood: "PLACEHOLDER_Mood",
        plannedDates: 2,
        nextDate: nil) }

    /// K4's widest case. The single-row variants are the same view with one card
    /// removed, and the copy for those is covered by `intro`'s switch.
    private static let bothMissing = ReinstallCleanup(widgetMissing: true,
                                                      notificationsOff: true)

    /// K5 with a name and keepsakes — the version that has to read as news
    /// rather than an error. `leftAt` is nil on purpose: it exercises the branch
    /// where the date is missing and the sentence has to hold up without it.
    private static var gone: PairGoneDetail { PairGoneDetail(partnerName: standInName,
                                             leftAt: nil,
                                             lettersKept: 6,
                                             remindersKept: 12) }
}

#endif
