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

    // 1 — HAPPY: pair codes normalize to a canonical uppercase form and the code
    // alphabet is the unambiguous 6-char set the invite contract promises.
    @Test("happy: pair-code normalization + alphabet contract")
    func pairCodeNormalizationContract() {
        // Both a hyphenated lowercase code and a space-separated uppercase code
        // collapse to the same canonical uppercase code.
        #expect(FirebaseService.normalizePairCode("7gk-4pb") == "7GK4PB")
        #expect(FirebaseService.normalizePairCode("7GK 4PB") == "7GK4PB")
        // A code the user types with stray separators still normalizes to 6 chars.
        #expect(FirebaseService.normalizePairCode("7gk-4pb").count == 6)

        // The alphabet excludes the visually ambiguous glyphs (0/O, 1/I/L) and is
        // entirely uppercase — so a normalized code can only contain these chars.
        let alphabet = FirebaseService.codeAlphabet
        for banned in ["0", "O", "1", "I", "L"] {
            #expect(!alphabet.contains(Character(banned)))
        }
        #expect(alphabet.allSatisfy { $0.isUppercase || $0.isNumber })
        // Every character produced by normalization is drawn from the alphabet.
        #expect(FirebaseService.normalizePairCode("7GK4PB").allSatisfy { alphabet.contains($0) })
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
