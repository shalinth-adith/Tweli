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
        guard let key = ProcessInfo.processInfo.environment["TWELI_RESTORE"] else { return }
        switch key {
        case "k2": app.applyRestoreCaptureState(phase: .restoring, steps: steps)
        case "k3": app.applyRestoreCaptureState(phase: .rejoined, summary: summary)
        case "k4": app.applyRestoreCaptureState(phase: .cleanup, pendingCleanup: bothMissing)
        case "k5": app.applyRestoreCaptureState(phase: .pairGone, gone: gone)
        default: break
        }
    }

    // MARK: - Stand-in states

    /// K2 mid-sequence: two rows settled, one working, one still to come. That
    /// combination is the interesting frame and also the hardest to catch live.
    private static let steps: [RestoreStep] = [
        RestoreStep(id: "account", title: "Account verified", state: .done),
        RestoreStep(id: "pair", title: "Pair found — PLACEHOLDER_Partner",
                    detail: "214 days", state: .done),
        RestoreStep(id: "items", title: "Reminders & letters",
                    detail: "18 of 24", state: .running),
        RestoreStep(id: "mood", title: "Their mood & planned dates"),
    ]

    /// K3 with all four stat rows populated, which is the layout worth checking.
    private static let summary = RestoreSummary(
        partnerName: "PLACEHOLDER_Partner",
        pairedDays: 214,
        reminders: 24, openReminders: 6,
        letters: 6, sealedLetters: 1,
        partnerMood: "PLACEHOLDER_Mood",
        plannedDates: 2,
        nextDate: nil)

    /// K4's widest case. The single-row variants are the same view with one card
    /// removed, and the copy for those is covered by `intro`'s switch.
    private static let bothMissing = ReinstallCleanup(widgetMissing: true,
                                                      notificationsOff: true)

    /// K5 with a name and keepsakes — the version that has to read as news
    /// rather than an error. `leftAt` is nil on purpose: it exercises the branch
    /// where the date is missing and the sentence has to hold up without it.
    private static let gone = PairGoneDetail(partnerName: "PLACEHOLDER_Partner",
                                             leftAt: nil,
                                             lettersKept: 6,
                                             remindersKept: 12)
}

#endif
