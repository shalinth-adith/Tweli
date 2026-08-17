//
//  StoreCapturePreviews.swift
//  Tweli
//
//  DEBUG ONLY. The whole file is inside `#if DEBUG`, so none of it exists in any
//  distribution build.
//
//  WHY THIS EXISTS
//
//  App Store screenshots have to come from a POPULATED space (APP_REVIEW.md §5),
//  and this app deliberately has no seeded content: `TWELI_SKIP_ONBOARDING=1`
//  writes an EMPTY CoupleSpace, so every screen renders its genuine empty state.
//  That is correct for the shipping build and useless for the store listing —
//  nobody installs an app on the strength of its empty states.
//
//  Reaching a real populated space needs two Apple IDs, a real pairing and hand-
//  entered content, on a 6.9" device, repeated every release. This paints the
//  same picture in memory in one launch.
//
//  WHY THE NAMES HERE ARE NOT `PLACEHOLDER_`
//
//  Every other stand-in in this repo is `PLACEHOLDER_`-prefixed so it is
//  greppable and unmistakably fake (see RestoreCapturePreviews). This file is
//  the deliberate exception, and the reason is the point of the file: these
//  strings are photographed and published as marketing material. "PLACEHOLDER_
//  Partner is feeling PLACEHOLDER_Mood" is not a screenshot anyone can ship.
//
//  What keeps that safe is not the naming convention but the compiler:
//    - the entire file is `#if DEBUG`, so it cannot link into a Release build;
//    - nothing here is written to Firestore, UserDefaults or the App Group —
//      `mergeRemote` is an in-memory merge and the process is thrown away when
//      the simulator app is killed;
//    - it is named `…Previews` so the repo's placeholder grep skips it.
//
//  Adding a `PLACEHOLDER_` here would defeat the file. Adding a Firestore write
//  would defeat the safety. Do neither.
//
//  USAGE
//
//    xcrun simctl launch <udid> me.adithyan.shalinth.Tweli   with:
//      SIMCTL_CHILD_TWELI_SKIP_ONBOARDING=1
//      SIMCTL_CHILD_TWELI_NO_LOCATION_ASK=1
//      SIMCTL_CHILD_TWELI_CAPTURE=1
//      SIMCTL_CHILD_TWELI_TAB=<0-3>
//
//  Light mode for the ML-series: `xcrun simctl ui <udid> appearance light`.
//

#if DEBUG

import Foundation

enum StoreCapture {

    /// The partner every store screenshot shows.
    static let partnerName = "Anaya"
    /// Must agree with the seeded location below.
    private static let partnerCity = "London"

    /// Seeds a populated space, or does nothing.
    ///
    /// Runs after the services exist, from RootView — the same seam
    /// `RestoreCapture` uses, and for the same reason: these objects are built
    /// by AppViewModel and cannot be reached from `AppEnvironment`'s
    /// UserDefaults-only launch hook.
    @MainActor
    static func applyIfNeeded(to app: AppViewModel, couple: CoupleSpaceService) {
        guard ProcessInfo.processInfo.environment["TWELI_CAPTURE"] == "1" else { return }
        // Idempotent: RootView's body can evaluate more than once, and merging
        // twice would double every list.
        guard !applied else { return }
        applied = true

        couple.updatePartnerName(partnerName)
        couple.updatePartnerDetails(bio: "Four and a half hours behind you.",
                                    city: partnerCity,
                                    birthday: nil)

        let me = couple.currentUser.id
        let them = couple.partner?.id ?? UUID()
        let space = couple.coupleSpace?.id ?? UUID()

        // Everything is dated RELATIVE to launch, so a screenshot taken in six
        // months still reads "2h ago" rather than a stale date. The mood is the
        // one that matters: the Home card's timing tag would otherwise announce
        // the exact day these fixtures were written.
        // The mood is the single most photographed element in the listing, so it
        // carries the warmest line we have rather than the saddest. "Missing
        // you" over a note about an empty bed is honest to the product and a
        // poor advertisement for it — the first screenshot should make someone
        // want the app, not feel the distance in it.
        app.moodService.mergeRemote([
            MoodStatus(userId: them, mood: .excitedToMeet,
                       note: "Counted it out on my fingers twice. Forty-one days.",
                       updatedAt: ago(minutes: 42)),
            MoodStatus(userId: me, mood: .content,
                       updatedAt: ago(hours: 3)),
        ], deletedIDs: [])

        // Two locations in two countries, which turns Home's "Share location"
        // prompt into a live distance readout and gives the globe sheet a real
        // route: London to Bengaluru, about 8,000 km.
        //
        // This pair only renders correctly because DistanceJourneyView now
        // projects the coordinates it is given. It used to draw every couple at
        // a hardcoded India–UAE pair while labelling those dots with the real
        // city names, and the first capture run with these two cities is what
        // exposed it.
        //
        // The globe's ROTATION is still fixed (a pre-projected coastline in
        // GlobeGeometry.json), so both cities must fall on the hemisphere it
        // shows. London and Bengaluru both do. Somewhere like Chile would be
        // clipped — see the note in DistanceJourneyView.
        // "You" is in Bengaluru, not London, and that is deliberate: several
        // surfaces label your own times with the DEVICE's zone (the Dates sheet
        // prints "YOU · IST"), and the capture simulator runs on IST. Putting
        // your pin in London produced a screenshot that said you were in London
        // and stamped your times IST — a contradiction a careful reader spots.
        // The partner carries the far-away city instead, which is also the more
        // natural read: you are the one holding the phone.
        app.locationService.mergeRemote([
            SharedLocation(userId: me,
                           latitude: 12.9716, longitude: 77.5946,
                           cityLabel: "Bengaluru",
                           timeZoneId: "Asia/Kolkata",
                           updatedAt: ago(minutes: 12)),
            SharedLocation(userId: them,
                           latitude: 51.5072, longitude: -0.1276,
                           cityLabel: "London",
                           timeZoneId: "Europe/London",
                           updatedAt: ago(minutes: 20)),
        ], deletedIDs: [])

        app.letterService.mergeRemote([
            OpenWhenLetter(title: "Open when you miss me",
                           message: "Then read this one twice, and remember the terminal.",
                           createdBy: them, coupleSpaceId: space,
                           isOpened: true, openedAt: ago(days: 2),
                           createdAt: ago(days: 6)),
            OpenWhenLetter(title: "Open when you land",
                           message: "I wrote this the night you booked it.",
                           createdBy: them, coupleSpaceId: space,
                           unlockDate: fromNow(days: 41),
                           createdAt: ago(days: 3)),
            OpenWhenLetter(title: "Open when it's a bad day",
                           message: "You are allowed to have one. Call me.",
                           createdBy: me, coupleSpaceId: space,
                           createdAt: ago(days: 9)),
        ], deletedIDs: [])

        app.reminderService.mergeRemote([
            ReminderItem(title: "Call before her stand-up",
                         note: "Her morning starts when your afternoon does.",
                         createdBy: them, coupleSpaceId: space,
                         reminderDate: fromNow(hours: 5),
                         repeatType: .weekly, priority: .important),
            ReminderItem(title: "Renew the passport",
                         createdBy: them, assignedTo: .partner, coupleSpaceId: space,
                         reminderDate: fromNow(days: 9)),
            ReminderItem(title: "Book the airport pickup",
                         createdBy: me, coupleSpaceId: space,
                         reminderDate: fromNow(days: 12)),
        ], deletedIDs: [])

        app.countdownService.mergeRemote([
            CountdownItem(title: "She flies in",
                          targetDate: fromNow(days: 41),
                          note: "Terminal 3, just before midnight.",
                          category: .meeting, isPinned: true,
                          createdBy: them, coupleSpaceId: space),
        ], deletedIDs: [])

        // Without these, Home's Dates card renders its "Plan your first date"
        // empty state — the one thing a store screenshot must never show.
        app.virtualDateService.mergeRemote([
            VirtualDateItem(title: "Watch the finale together",
                            date: fromNow(days: 2),
                            notes: "Press play on three.",
                            coupleSpaceId: space, createdBy: them),
            VirtualDateItem(title: "Cook the same thing",
                            date: fromNow(days: 6),
                            coupleSpaceId: space, createdBy: me),
        ], deletedIDs: [])

        // A 42-minute-old partner mood is, correctly, a FRESH one — so the app
        // raises the full-screen "New mood" interstitial over whatever tab was
        // asked for, and every screenshot came back with a modal across it.
        //
        // Acknowledging it here is not faking anything away: it is the state of
        // someone who has already seen the mood and is now using the app, which
        // is exactly the state a store screenshot should show. The mood stays
        // fresh on the Home card ("42 minutes ago"); only the one-time
        // interstitial is settled.
        //
        // Capture it deliberately with TWELI_MOOD_CARD if you want it — it is a
        // good screenshot in its own right, just not on top of three others.
        app.moodService.acknowledgePartnerMood()
        app.freshMood = nil
    }

    private static var applied = false

    // MARK: - Relative dates

    private static func ago(minutes: Int = 0, hours: Int = 0, days: Int = 0) -> Date {
        Date().addingTimeInterval(-Double(minutes * 60 + hours * 3600 + days * 86400))
    }

    private static func fromNow(hours: Int = 0, days: Int = 0) -> Date {
        Date().addingTimeInterval(Double(hours * 3600 + days * 86400))
    }
}

#endif
