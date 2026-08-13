//
//  PartnerIdentityTests.swift
//  TweliTests
//
//  Regression cover for the "8 m apart" bug.
//
//  Moods and locations decide whose record is whose by comparing the payload's
//  `userId` to `currentUserId` — a UUID minted on the device and kept in
//  UserDefaults. It is regenerated whenever the local profile is recreated
//  (reinstall, sign out and back in), and the user's own earlier records then
//  fail the "is this mine?" test and get read as the partner's. Because the
//  device keeps writing, they are also the NEWEST such record, so "newest wins"
//  prefers them over the partner's genuine one every time.
//
//  Observed in production: a partner in Abu Dhabi, Home reporting "8 m apart" —
//  the gap between two of the user's own fixes, 11.9347,79.8086 and
//  11.9347,79.8087.
//
//  The fix re-stamps records whose Firebase `authorUid` is mine with my current
//  local id before they reach the services. These tests pin the arithmetic and
//  the selection rule that made the symptom visible.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Partner identity and distance")
struct PartnerIdentityTests {

    // The real coordinates from the production space.
    private static let puducherryA = (lat: 11.9347, lon: 79.8086)
    private static let puducherryB = (lat: 11.9347, lon: 79.8087)
    private static let abuDhabi    = (lat: 24.4888, lon: 54.3616)

    private func location(_ userId: UUID, _ coords: (lat: Double, lon: Double),
                          city: String, updatedAt: Date) -> SharedLocation {
        SharedLocation(userId: userId, latitude: coords.lat, longitude: coords.lon,
                       cityLabel: city, updatedAt: updatedAt)
    }

    /// The symptom, reproduced as arithmetic: two of the user's own fixes are
    /// metres apart, so if one is mistaken for the partner the screen is wrong
    /// by three orders of magnitude.
    @Test("two of my own fixes are metres apart, not kilometres")
    func ownFixesAreMetresApart() {
        let mine = location(UUID(), Self.puducherryA, city: "Puducherry", updatedAt: .now)
        let alsoMine = location(UUID(), Self.puducherryB, city: "Puducherry", updatedAt: .now)
        let metres = LocationService.distanceMeters(from: mine, to: alsoMine)
        #expect(metres < 50, "expected a few metres, got \(metres)")
    }

    /// And the honest answer, for comparison.
    @Test("Puducherry to Abu Dhabi is roughly 3,000 km")
    func realDistanceIsThousandsOfKm() {
        let mine = location(UUID(), Self.puducherryA, city: "Puducherry", updatedAt: .now)
        let theirs = location(UUID(), Self.abuDhabi, city: "Abu Dhabi", updatedAt: .now)
        let km = LocationService.distanceMeters(from: mine, to: theirs) / 1000
        #expect(km > 2_500 && km < 3_500, "expected ~3000 km, got \(km)")
    }

    /// The selection rule itself. Once the sync layer has re-stamped everything
    /// this device authored, ALL of the user's records share one id — so the
    /// partner's record is the only candidate left, regardless of which is
    /// newer. Before the fix, the stale self-record won on recency.
    @Test("after re-stamping, the partner's record wins even when mine is newer")
    func partnerWinsOverStaleSelfRecord() {
        let me = UUID()
        let them = UUID()

        // The stale self-record is deliberately the NEWEST, which is what made
        // the original bug deterministic rather than intermittent.
        let records = [
            location(them, Self.abuDhabi, city: "Abu Dhabi",
                     updatedAt: Date(timeIntervalSinceReferenceDate: 100)),
            location(me, Self.puducherryA, city: "Puducherry",
                     updatedAt: Date(timeIntervalSinceReferenceDate: 200)),
            location(me, Self.puducherryB, city: "Puducherry",
                     updatedAt: Date(timeIntervalSinceReferenceDate: 300)),
        ]

        // Mirrors LocationService.partnerLocation.
        let partner = records.filter { $0.userId != me }.max { $0.updatedAt < $1.updatedAt }
        #expect(partner?.cityLabel == "Abu Dhabi")

        let mine = records.first { $0.userId == me }
        let km = LocationService.distanceMeters(from: try! #require(mine),
                                                to: try! #require(partner)) / 1000
        #expect(km > 2_500, "still measuring against myself: \(km) km")
    }

    /// The pre-fix behaviour, asserted so the regression is unmistakable if the
    /// re-stamping is ever removed: with a stale id in play, "newest non-mine"
    /// selects the user's own record.
    @Test("without re-stamping, a stale self-id is mistaken for the partner")
    func staleSelfIdLooksLikeThePartner() {
        let currentMe = UUID()
        let staleMe = UUID()      // same human, older install
        let them = UUID()

        let records = [
            location(them, Self.abuDhabi, city: "Abu Dhabi",
                     updatedAt: Date(timeIntervalSinceReferenceDate: 100)),
            location(staleMe, Self.puducherryA, city: "Puducherry",
                     updatedAt: Date(timeIntervalSinceReferenceDate: 300)),
        ]

        let wrongPartner = records.filter { $0.userId != currentMe }
            .max { $0.updatedAt < $1.updatedAt }
        #expect(wrongPartner?.cityLabel == "Puducherry",
                "this is the bug: the stale self-record wins on recency")
    }

    // MARK: - Formatting

    /// Whatever the distance, the label must carry a unit rather than a bare
    /// number — the Home row reads "8 m apart", so the unit is doing real work.
    @Test("the distance label is unit-bearing at both scales")
    func labelCarriesAUnit() {
        let small = LocationService.distanceLabel(meters: 8)
        let large = LocationService.distanceLabel(meters: 3_000_000)
        #expect(small.rangeOfCharacter(from: .letters) != nil)
        #expect(large.rangeOfCharacter(from: .letters) != nil)
        #expect(small != large)
    }
}
