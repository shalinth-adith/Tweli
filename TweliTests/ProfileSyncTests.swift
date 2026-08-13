//
//  ProfileSyncTests.swift
//  TweliTests
//
//  The X1–X6 flow collects five things. Two of them (name, timezone) already
//  reached the partner; three (bio, city, birthday) were written to UserDefaults
//  and went nowhere, while comp X6 told the user "this is what they see". These
//  tests pin the parts of that wiring that can be checked without Firestore.
//
//  What is covered here: the name composition that produces the cloud-visible
//  `displayName`, and the birthday wire format. What is NOT covered: the actual
//  Firestore write and snapshot read, which need a live project or the emulator.
//  Those are verified by hand — see docs/APP_REVIEW.md.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Profile sync")
struct ProfileSyncTests {

    // MARK: - Name composition

    @Test("first + last compose into the cloud-visible display name")
    func composesBothParts() {
        var p = UserProfile(displayName: "", avatarEmoji: "💛")
        p.firstName = "Shalinth"
        p.lastName = "Rajan"
        #expect(p.composedName == "Shalinth Rajan")
    }

    @Test("a missing last name does not leave a trailing space")
    func composesFirstOnly() {
        var p = UserProfile(displayName: "", avatarEmoji: "💛")
        p.firstName = "Shalinth"
        p.lastName = "   "
        #expect(p.composedName == "Shalinth")
    }

    /// Profiles created before X1–X6 have empty name parts and a populated
    /// `displayName`. If `composedName` returned "" for them, the flow would
    /// wipe the name of every existing user on first save.
    @Test("a legacy profile keeps its existing display name")
    func legacyProfileFallsBack() {
        let p = UserProfile(displayName: "Anaya", avatarEmoji: "💛")
        #expect(p.firstName.isEmpty)
        #expect(p.composedName == "Anaya")
    }

    // MARK: - Birthday wire format

    /// Birthdays cross the wire as `yyyy-MM-dd` in UTC rather than as a
    /// Timestamp. A Timestamp carries an instant, and an instant read back in
    /// another zone lands on the day before — which for a birthday nudge means
    /// firing on the wrong date for every long-distance couple, i.e. all of them.
    @Test("a birthday round-trips to the same calendar day")
    func birthdayRoundTrips() throws {
        let f = FirebaseService.birthdayFormatter
        var comps = DateComponents()
        comps.year = 1999; comps.month = 9; comps.day = 13
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let original = try #require(cal.date(from: comps))

        let wire = f.string(from: original)
        #expect(wire == "1999-09-13")

        let parsed = try #require(f.date(from: wire))
        let back = cal.dateComponents([.year, .month, .day], from: parsed)
        #expect(back.year == 1999)
        #expect(back.month == 9)
        #expect(back.day == 13)
    }

    /// The formatter must not drift when the device is far from UTC. Pinning its
    /// own timeZone is what makes this hold; without it a device in UTC+14 or
    /// UTC-11 reads the date off by one.
    @Test("the wire format is independent of the device time zone")
    func birthdayIsZoneIndependent() throws {
        let f = FirebaseService.birthdayFormatter
        let parsed = try #require(f.date(from: "2001-01-01"))

        for identifier in ["Pacific/Kiritimati", "Pacific/Midway", "Asia/Kolkata"] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            let c = cal.dateComponents([.year, .month, .day], from: parsed)
            #expect(c.year == 2001, "drifted reading from \(identifier)")
            #expect(c.month == 1)
            #expect(c.day == 1)
        }
        // And the string it produces is stable regardless of who formats it.
        #expect(f.string(from: parsed) == "2001-01-01")
    }

    // MARK: - Reading the partner's half out of a space document

    private static let me = "uid-me"
    private static let them = "uid-them"

    /// A space doc shaped exactly as `updateMyProfileDetails` writes it.
    private func spaceDoc(bio: String? = nil, city: String? = nil,
                          birthday: String? = nil) -> [String: Any] {
        var doc: [String: Any] = [
            "memberUids": [Self.me, Self.them],
            "memberNames": [Self.me: "Shalinth", Self.them: "Anaya"],
        ]
        if let bio { doc["memberBios"] = [Self.them: bio] }
        if let city { doc["memberCities"] = [Self.them: city] }
        if let birthday { doc["memberBirthdays"] = [Self.them: birthday] }
        return doc
    }

    @Test("the partner's profile is read off the space document")
    func readsPartnerDetails() throws {
        var changes = FirebaseService.RemoteChanges()
        FirebaseService.applyPartnerDetails(
            from: spaceDoc(bio: "Night owl, terrible at goodbyes.",
                           city: "Abu Dhabi",
                           birthday: "1999-09-13"),
            partnerUid: Self.them, into: &changes)

        #expect(changes.partnerBio == "Night owl, terrible at goodbyes.")
        #expect(changes.partnerCity == "Abu Dhabi")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = cal.dateComponents([.year, .month, .day],
                                     from: try #require(changes.partnerBirthday))
        #expect(day.year == 1999)
        #expect(day.month == 9)
        #expect(day.day == 13)
    }

    /// A partner who skipped these steps must read as nil, not as "".
    @Test("absent fields read as nil rather than empty strings")
    func absentFieldsAreNil() {
        var changes = FirebaseService.RemoteChanges()
        FirebaseService.applyPartnerDetails(from: spaceDoc(),
                                            partnerUid: Self.them, into: &changes)
        #expect(changes.partnerBio == nil)
        #expect(changes.partnerCity == nil)
        #expect(changes.partnerBirthday == nil)
    }

    /// Whitespace-only values would render as a blank quoted line in the hero.
    @Test("blank fields are treated as absent")
    func blankFieldsAreNil() {
        var changes = FirebaseService.RemoteChanges()
        FirebaseService.applyPartnerDetails(from: spaceDoc(bio: "   ", city: ""),
                                            partnerUid: Self.them, into: &changes)
        #expect(changes.partnerBio == nil)
        #expect(changes.partnerCity == nil)
    }

    /// The map is keyed by uid, and reading the wrong key would show the user
    /// their OWN bio labelled as their partner's.
    @Test("only the partner's entry is read, never your own")
    func doesNotReadOwnEntry() {
        var doc = spaceDoc(bio: "Their bio")
        doc["memberBios"] = [Self.me: "My bio", Self.them: "Their bio"]

        var changes = FirebaseService.RemoteChanges()
        FirebaseService.applyPartnerDetails(from: doc, partnerUid: Self.them, into: &changes)
        #expect(changes.partnerBio == "Their bio")
    }

    /// A malformed date must not crash or silently produce a wrong day.
    @Test("an unparseable birthday is dropped, not guessed")
    func badBirthdayIsDropped() {
        var changes = FirebaseService.RemoteChanges()
        FirebaseService.applyPartnerDetails(from: spaceDoc(birthday: "13/09/1999"),
                                            partnerUid: Self.them, into: &changes)
        #expect(changes.partnerBirthday == nil)
    }
}
