//
//  ReviewDemoPayloadTests.swift
//  TweliTests
//
//  Guards the wire format that `scripts/seed-review-demo.js` writes.
//
//  Why this is worth a test: the demo space App Review joins is seeded by a
//  Node script, not by the app, so nothing in the normal build path checks that
//  what it writes is what Swift reads. A mismatch does not throw anywhere a
//  human would see it — the sync layer just decodes nothing and the reviewer
//  opens a space that looks empty, which reads as a broken app.
//
//  Two encoding details carry all the risk, because both fail quietly:
//    - a stock JSONEncoder writes Date as .deferredToDate, i.e. seconds since
//      2001-01-01Z, so a seed using the Unix epoch lands 31 years in the future;
//    - UUID encodes uppercase.
//
//  The payloads below are copied verbatim from the script's output. If you
//  change the models or the script, regenerate them.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Review demo payloads")
struct ReviewDemoPayloadTests {

    private let decoder = JSONDecoder()

    /// 2026-08-13 09:00:00Z expressed the way the script writes it.
    private let expectedInstant = Date(timeIntervalSinceReferenceDate: 808_304_400)

    @Test("A seeded mood decodes as the partner's mood")
    func moodDecodes() throws {
        let json = """
        {"id":"6BAF297B-C982-4318-B7BE-093B36A1D8C0",\
        "userId":"4016CA1D-068F-4795-8180-D53D360FBE21",\
        "mood":"missingYou","note":"Long day.","updatedAt":808304400}
        """
        let mood = try decoder.decode(MoodStatus.self, from: Data(json.utf8))

        #expect(mood.mood == .missingYou)
        #expect(mood.note == "Long day.")
        #expect(mood.updatedAt == expectedInstant)
        // MoodService treats "not authored by me" as the partner's, so the id
        // only has to be a well-formed UUID that is not the local user's.
        #expect(mood.userId.uuidString == "4016CA1D-068F-4795-8180-D53D360FBE21")
    }

    @Test("A seeded countdown decodes with the right target date")
    func countdownDecodes() throws {
        let json = """
        {"id":"14AA1071-A80D-42E3-AD69-D6EA87862ED9","title":"She flies in",\
        "targetDate":811893600,"note":"Terminal 3.","category":"meeting",\
        "isPinned":true,"createdBy":"4016CA1D-068F-4795-8180-D53D360FBE21",\
        "coupleSpaceId":"7605A492-CB4B-41EC-8977-4A7715D83988","createdAt":808304400}
        """
        let item = try decoder.decode(CountdownItem.self, from: Data(json.utf8))

        #expect(item.title == "She flies in")
        #expect(item.category == .meeting)
        #expect(item.isPinned)
        #expect(item.targetDate == Date(timeIntervalSinceReferenceDate: 811_893_600))
    }

    /// The regression this whole file exists for: seconds-since-1970 in a field
    /// Swift reads as seconds-since-2001 decodes without error, just to a date
    /// three decades out. Only an assertion on the value catches it.
    @Test("Unix-epoch seconds would land decades in the future")
    func unixEpochWouldBeWrong() {
        let unixStyle = Date(timeIntervalSinceReferenceDate: 1_786_000_000)
        let year = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(identifier: "UTC")!, from: unixStyle).year
        #expect(year == 2057)
    }

    /// Swift's UUID(uuidString:) accepts lowercase, so a lowercase seed decodes
    /// fine — this pins that, so nobody "fixes" the script's uppercasing and
    /// assumes it mattered here. What must NOT change is the date epoch.
    @Test("Lowercase UUIDs still decode")
    func lowercaseUUIDDecodes() throws {
        let json = """
        {"id":"6baf297b-c982-4318-b7be-093b36a1d8c0",\
        "userId":"4016ca1d-068f-4795-8180-d53d360fbe21",\
        "mood":"calm","updatedAt":808304400}
        """
        let mood = try decoder.decode(MoodStatus.self, from: Data(json.utf8))
        #expect(mood.mood == .calm)
    }
}
