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
