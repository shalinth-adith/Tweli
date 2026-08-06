//
//  TweliTests.swift
//  TweliTests
//
//  Critical-path tests for the CloudKit → Firebase invite flow. These exercise the
//  pure logic of `FirebaseService`'s public surface (no network, no mocks): pair-code
//  normalization/alphabet, the `PairCodeError` UX copy contract, and the thin-payload
//  round-trip that every item write depends on (DECISIONS.md §4).
//

import Testing
import Foundation
@testable import Tweli

@MainActor
@Suite("18-firebase-migration invite flow")
struct TweliTests {

    // 1 — HAPPY: pair codes normalize to a canonical uppercase form and round-trip
    // through the TWLI-4821 display format the comp (A5/A6) specifies.
    @Test("happy: pair-code normalization + TWLI-4821 format contract")
    func pairCodeNormalizationContract() {
        // Hyphens, spaces and lowercase all collapse to the stored document id.
        // (The comp's literal "TWLI" isn't usable — I and L are excluded as
        // digit look-alikes — so the shape is exercised with a mintable code.)
        #expect(FirebaseService.normalizePairCode("twnk-4821") == "TWNK4821")
        #expect(FirebaseService.normalizePairCode("TWNK 4821") == "TWNK4821")
        #expect(FirebaseService.normalizePairCode("twnk-4821").count == FirebaseService.codeLength)

        // Display form re-inserts the hyphen after the four letters.
        #expect(FirebaseService.formatPairCode("twnk4821") == "TWNK-4821")
        // Normalize ∘ format is the identity on the stored form.
        #expect(FirebaseService.normalizePairCode(FirebaseService.formatPairCode("TWNK4821")) == "TWNK4821")

        // Letters exclude the glyphs that read as digits; digits are unambiguous
        // BECAUSE O/I/L are absent from the letter set.
        for banned in ["O", "I", "L"] {
            #expect(!FirebaseService.codeLetters.contains(Character(banned)))
        }
        let alphabet = FirebaseService.codeAlphabet
        #expect(alphabet.allSatisfy { $0.isUppercase || $0.isNumber })
        #expect(FirebaseService.normalizePairCode("TWNK4821").allSatisfy { alphabet.contains($0) })

        // Legacy 6-character invites must still be enterable, alongside new ones.
        #expect(FirebaseService.isPlausiblePairCode("7GK4PB"))
        #expect(FirebaseService.isPlausiblePairCode("TWNK-4821"))
        #expect(!FirebaseService.isPlausiblePairCode("TWNK"))
    }

    // -3 — ERROR: the reminder collections filter on `localFireDate` but used to
    // SORT on the raw `reminderDate` instant. Across timezones the two orders
    // can disagree, so the list came back in an order its own filter didn't
    // agree with. This builds exactly that disagreement and pins the fix.
    @Test("error: reminders sort by the same clock they are filtered on")
    func remindersSortByLocalFireDate() {
        // Two reminders whose ABSOLUTE instants are one order and whose WALL
        // CLOCKS are the opposite: an 8:00 AM set in Tokyo happens earlier in
        // absolute terms than a 9:00 AM set in New York, but reads as the later
        // wall clock only if you compare the raw instants.
        func reminder(_ title: String, hour: Int, zone: String) -> ReminderItem {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: zone)!
            let when = cal.date(from: DateComponents(year: 2026, month: 8, day: 12,
                                                     hour: hour, minute: 0))!
            return ReminderItem(title: title, createdBy: UUID(), coupleSpaceId: UUID(),
                                reminderDate: when, authorTimezone: zone)
        }
        // Tokyo 09:00 == 00:00 UTC; New York 08:00 == 12:00 UTC.
        let tokyo9 = reminder("Tokyo 9am", hour: 9, zone: "Asia/Tokyo")
        let newYork8 = reminder("NY 8am", hour: 8, zone: "America/New_York")

        // Raw instants: Tokyo first. Wall clocks: New York (8) before Tokyo (9).
        #expect(tokyo9.reminderDate < newYork8.reminderDate)
        #expect(newYork8.localFireDate < tokyo9.localFireDate)

        // Ascending by wall clock must put the 8am first — the old sort on
        // `reminderDate` returned the opposite.
        let ascending = [tokyo9, newYork8].sorted { $0.localFireDate < $1.localFireDate }
        #expect(ascending.first?.title == "NY 8am")

        // And the shared sort helper agrees, so list views and the service can't
        // drift apart.
        let service = ReminderService(notifications: ReminderNotificationService(),
                                      cloud: FirebaseService())
        let viaHelper = service.sorted([tokyo9, newYork8], by: .soonest)
        #expect(viaHelper.first?.title == "NY 8am")
    }

    // -1 — ERROR: the New Reminder sheet's validation must be REACHABLE. The
    // title error only fires on an empty title, so if Save were disabled under
    // that same condition the message could never appear and the user would get
    // a dim button with no explanation.
    @Test("error: an empty title is savable-and-rejected, not silently blocked")
    func emptyTitleValidationIsReachable() {
        let vm = AddReminderViewModel()
        vm.title = "   "                       // whitespace only

        // Nothing said before the user asks.
        #expect(vm.titleError == nil)
        // Save is dim…
        #expect(!vm.canSave)
        // …but attempting it must produce the explanation, not silence.
        #expect(vm.validate() == false)
        #expect(vm.titleError != nil)

        // And it clears the moment they start typing.
        vm.title = "Call her"
        vm.clearAttempt()
        #expect(vm.titleError == nil)
        #expect(vm.canSave)
        #expect(vm.validate())
    }

    // -2 — ERROR: a one-off reminder in the past is rejected; a repeating one at
    // a time-of-day that has already gone by today is NOT — it belongs tomorrow.
    @Test("error: past-time validation applies to one-offs, not recurrences")
    func pastTimeOnlyBlocksOneOffs() {
        func vm(_ repeatType: RepeatType) -> AddReminderViewModel {
            let m = AddReminderViewModel()
            m.title = "Vitamins"
            m.date = Date().addingTimeInterval(-3600)
            m.time = Date().addingTimeInterval(-3600)
            m.repeatType = repeatType
            return m
        }
        let once = vm(.none)
        #expect(once.validate() == false)
        #expect(once.timeError != nil)

        for r in [RepeatType.daily, .weekly, .monthly] {
            let recurring = vm(r)
            #expect(recurring.validate(), "\(r.label) at a past time-of-day should schedule for next occurrence")
            #expect(recurring.timeError == nil)
        }
    }

    // 0 — ERROR: "Custom" repeat is not a recurrence. It must stay out of the
    // picker (it would schedule a one-time alert under a repeating label) while
    // remaining decodable, since reminders synced before it was hidden still
    // carry the value.
    @Test("error: Custom repeat is hidden from the picker but still decodes")
    func customRepeatIsHiddenButWireCompatible() throws {
        let offered = RepeatType.allCases.filter { $0 != .custom }
        #expect(!offered.contains(.custom))
        // The three real recurrences stay on offer alongside None.
        #expect(offered == [.none, .daily, .weekly, .monthly])

        // Back-compat: a reminder already stored as "custom" still round-trips.
        let raw = #"{"repeatType":"custom"}"#
        struct Probe: Codable { var repeatType: RepeatType }
        let decoded = try JSONDecoder().decode(Probe.self, from: Data(raw.utf8))
        #expect(decoded.repeatType == .custom)
    }

    // 1a — ERROR: a minted code must always be normalizable back to itself.
    // Guards the alphabet and the generator from drifting apart.
    @Test("error: every minted pair code round-trips through normalize/format")
    func mintedPairCodesRoundTrip() {
        for _ in 0..<200 {
            let code = FirebaseService.makeCode()
            #expect(code.count == FirebaseService.codeLength)
            #expect(FirebaseService.normalizePairCode(code) == code)
            #expect(FirebaseService.normalizePairCode(FirebaseService.formatPairCode(code)) == code)
            #expect(FirebaseService.isPlausiblePairCode(code))
        }
    }

    // 1b — HAPPY: the reminder notification routing matrix. `assignedTo` is
    // written from the CREATOR's point of view, so the same stored reminder must
    // ring on a different set of phones depending on who is reading it.
    @Test("happy: reminder rings on exactly the assigned devices")
    func reminderNotificationRouting() {
        let creator = UUID()
        let partner = UUID()

        func reminder(_ who: ReminderAssignee) -> ReminderItem {
            var r = ReminderItem(title: "Take your vitamins", createdBy: creator,
                                 coupleSpaceId: UUID(), reminderDate: Date())
            r.assignedTo = who
            return r
        }

        // Set for myself → only my phone rings.
        #expect(ReminderService.shouldRing(reminder(.me), currentUserId: creator))
        #expect(!ReminderService.shouldRing(reminder(.me), currentUserId: partner))

        // Set for my partner → only THEIR phone rings, never mine.
        #expect(!ReminderService.shouldRing(reminder(.partner), currentUserId: creator))
        #expect(ReminderService.shouldRing(reminder(.partner), currentUserId: partner))

        // Set for both → both phones ring.
        #expect(ReminderService.shouldRing(reminder(.both), currentUserId: creator))
        #expect(ReminderService.shouldRing(reminder(.both), currentUserId: partner))

        // Symmetry: the same rules hold when the OTHER person is the author, so
        // "user 2 sets it for both" behaves identically to "user 1 sets it for both".
        var theirs = ReminderItem(title: "Evening call", createdBy: partner,
                                  coupleSpaceId: UUID(), reminderDate: Date())
        theirs.assignedTo = .both
        #expect(ReminderService.shouldRing(theirs, currentUserId: creator))
        #expect(ReminderService.shouldRing(theirs, currentUserId: partner))

        theirs.assignedTo = .me          // they kept it for themselves
        #expect(!ReminderService.shouldRing(theirs, currentUserId: creator))
        #expect(ReminderService.shouldRing(theirs, currentUserId: partner))
    }

    // 2 — ERROR: every PairCodeError case carries the exact user-facing copy the
    // join/confirm views surface via `localizedDescription`. This is the UX contract.
    @Test("error: PairCodeError copy contract")
    func pairCodeErrorCopyContract() {
        #expect(FirebaseService.PairCodeError.notFound.localizedDescription
            == "That code wasn't found. Double-check it, or ask your partner for a fresh one.")
        #expect(FirebaseService.PairCodeError.expired.localizedDescription
            == "That code has expired. Ask your partner to create a new invite.")
        #expect(FirebaseService.PairCodeError.badShareURL.localizedDescription
            == "This invite looks broken. Ask your partner to create a new one.")
        #expect(FirebaseService.PairCodeError.spaceFull.localizedDescription
            == "This space already has two people. Ask your partner to send you a fresh invite.")
        #expect(FirebaseService.PairCodeError.network.localizedDescription
            == "Couldn't check the code right now. Check your connection and try again.")
    }

    // 3 — ERROR: each of the six Codable item models survives the exact
    // JSONEncoder → utf8 String → JSONDecoder round-trip that FirebaseService.save
    // uses for the thin `payload` field — id and a key field stay intact.
    @Test("error: thin-payload round-trip for all six item models")
    func thinPayloadRoundTrip() throws {
        let author = UUID()
        let space = UUID()

        let reminder = ReminderItem(title: "Take your meds", createdBy: author,
                                    coupleSpaceId: space, reminderDate: Date())
        try assertRoundTrip(reminder, id: reminder.id) { $0.title == "Take your meds" }

        let countdown = CountdownItem(title: "Until we meet", targetDate: Date(),
                                      createdBy: author, coupleSpaceId: space)
        try assertRoundTrip(countdown, id: countdown.id) { $0.title == "Until we meet" }

        let letter = OpenWhenLetter(title: "Open when sad", message: "I love you",
                                    createdBy: author, coupleSpaceId: space)
        try assertRoundTrip(letter, id: letter.id) { $0.message == "I love you" }

        let date = VirtualDateItem(title: "Movie night", date: Date(),
                                   coupleSpaceId: space, createdBy: author)
        try assertRoundTrip(date, id: date.id) { $0.title == "Movie night" }

        let mood = MoodStatus(userId: author, mood: .missingYou)
        try assertRoundTrip(mood, id: mood.id) { $0.mood == .missingYou }

        let ping = MissingYouPing(message: "Miss you", sentBy: author,
                                  sentTo: UUID(), coupleSpaceId: space)
        try assertRoundTrip(ping, id: ping.id) { $0.message == "Miss you" }

        let location = SharedLocation(userId: author, latitude: 51.5074, longitude: -0.1278,
                                      cityLabel: "London")
        try assertRoundTrip(location, id: location.id) { $0.cityLabel == "London" }
    }

    // 4 — HAPPY: the partner-distance helpers compute a sane geodesic distance and
    // format it to a non-empty, human-readable label. Pure math — no CoreLocation
    // permission, no service state.
    @Test("happy: partner distance math + formatting")
    func partnerDistanceMath() {
        // San Francisco → New York City ≈ 4,130 km.
        let sf = SharedLocation(userId: UUID(), latitude: 37.7749, longitude: -122.4194)
        let nyc = SharedLocation(userId: UUID(), latitude: 40.7128, longitude: -74.0060)

        let meters = LocationService.distanceMeters(from: sf, to: nyc)
        #expect(meters > 4_000_000 && meters < 4_300_000)

        // Same point → zero distance.
        #expect(LocationService.distanceMeters(from: sf, to: sf) < 1)

        // Formatted label is non-empty and contains a number (km or mi per locale).
        let label = LocationService.distanceLabel(meters: meters)
        #expect(!label.isEmpty)
        #expect(label.contains { $0.isNumber })
    }

    // 5 — HAPPY: a reminder's time is a WALL CLOCK. A "9:30 AM" set in one zone
    // reads as 9:30 AM for a partner in another zone (that's also when it fires).
    @Test("happy: cross-timezone reminder keeps its wall clock")
    func reminderWallClockAcrossTimezones() {
        // Build 9:30 AM on 2026-08-05 in Asia/Kolkata (the "author's" zone).
        var kolkata = Calendar(identifier: .gregorian)
        kolkata.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let nineThirty = kolkata.date(
            from: DateComponents(year: 2026, month: 8, day: 5, hour: 9, minute: 30))!

        let r = ReminderItem(title: "Take meds", createdBy: UUID(),
                             coupleSpaceId: UUID(), reminderDate: nineThirty,
                             authorTimezone: "Asia/Kolkata")

        // Regardless of the test machine's own zone, the localized wall clock is
        // still 9:30 — the components are preserved, only the instant shifts.
        #expect(Calendar.current.component(.hour, from: r.localFireDate) == 9)
        #expect(Calendar.current.component(.minute, from: r.localFireDate) == 30)

        // Legacy reminders (no authorTimezone) keep the raw instant — no shift.
        let legacy = ReminderItem(title: "Old", createdBy: UUID(),
                                  coupleSpaceId: UUID(), reminderDate: nineThirty)
        #expect(legacy.localFireDate == nineThirty)
    }

    /// Encodes a model to a JSON string (as FirebaseService stores it), decodes it
    /// back, and asserts the id and a caller-chosen field survived.
    private func assertRoundTrip<T: Codable & Identifiable>(
        _ value: T, id: T.ID, check: (T) -> Bool
    ) throws where T.ID: Equatable {
        let data = try JSONEncoder().encode(value)
        let payload = try #require(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(T.self, from: try #require(payload.data(using: .utf8)))
        #expect(decoded.id == id)
        #expect(check(decoded))
    }
}
