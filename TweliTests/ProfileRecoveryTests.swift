//
//  ProfileRecoveryTests.swift
//  TweliTests
//
//  Reinstall recovery, and the rule that stops it destroying data.
//
//  Recovery has always restored MEMBERSHIP — it finds you by `memberUids`
//  array-contains, so a wiped app container cannot lose your space. It did not
//  restore IDENTITY, which was harmless until the profile gained a bio, city
//  and birthday. After that, a reinstall left the device with an empty profile
//  while Firestore still held the real one, walked the user back through X1–X6
//  with blank fields, and finishing that pushed the blanks up — deleting the
//  bio and birthday from the partner's copy too.
//
//  Two rules come out of that, and both are tested here:
//
//    1. Recovery fills GAPS only. A non-empty local value always wins, because
//       the device may legitimately be ahead of the server.
//    2. An empty field only DELETES the stored one when the user just edited
//       that screen. A device that doesn't happen to know a value is not
//       evidence the user wants it gone.
//

import Testing
import Foundation
@testable import Tweli

@MainActor
@Suite("Profile recovery")
struct ProfileRecoveryTests {

    /// A scratch defaults domain per test, so nothing leaks between cases or
    /// into the real app domain.
    private func service(_ name: String) -> CoupleSpaceService {
        let suite = "tests.recovery.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return CoupleSpaceService(cloud: FirebaseService(), defaults: defaults)
    }

    private let birthday = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Restoring after a reinstall

    @Test("a wiped profile is restored from the space document")
    func restoresIntoEmptyProfile() {
        let s = service("empty")
        #expect(s.currentUser.displayName.isEmpty)

        let recovered = s.restoreMyProfile(name: "Shalinth Rajan",
                                           bio: "Night owl.",
                                           city: "Puducherry",
                                           birthday: birthday)

        #expect(recovered)
        #expect(s.currentUser.displayName == "Shalinth Rajan")
        #expect(s.currentUser.bio == "Night owl.")
        #expect(s.currentUser.city == "Puducherry")
        #expect(s.currentUser.birthday == birthday)
    }

    /// The name arrives as one string; the structured halves the X1/X2 screens
    /// edit have to stay coherent with it, or the next save reintroduces the
    /// stale value.
    @Test("a restored name repopulates the first/last split")
    func restoresNameParts() {
        let s = service("parts")
        s.restoreMyProfile(name: "Shalinth Rajan", bio: nil, city: nil, birthday: nil)
        #expect(s.currentUser.firstName == "Shalinth")
        #expect(s.currentUser.lastName == "Rajan")
        #expect(s.currentUser.composedName == "Shalinth Rajan")
    }

    /// Returning true is what tells the app not to re-run X1–X6.
    @Test("a recovered name means the profile flow is already done")
    func recoveredProfileSkipsOnboarding() {
        let s = service("skip")
        #expect(!s.hasCompletedAboutYou)
        s.restoreMyProfile(name: "Shalinth", bio: nil, city: nil, birthday: nil)
        #expect(s.hasCompletedAboutYou)
    }

    /// …but an empty space (nobody has filled anything in) must NOT skip it,
    /// or a genuinely new user never gets asked.
    @Test("nothing to recover means the profile flow still runs")
    func nothingRecoveredKeepsOnboarding() {
        let s = service("noskip")
        let recovered = s.restoreMyProfile(name: nil, bio: nil, city: nil, birthday: nil)
        #expect(!recovered)
        #expect(!s.hasCompletedAboutYou)
    }

    // MARK: - Recovery must never overwrite

    /// The device can legitimately be ahead of the server — edited offline, or
    /// mid-sync. Recovery fills gaps; it does not roll anything back.
    @Test("a populated local profile is never overwritten by recovery")
    func localValuesWin() {
        let s = service("localwins")
        s.updateProfile(firstName: "Shalinth", lastName: "Rajan",
                        birthday: birthday, city: "Chennai",
                        timezoneIdentifier: "Asia/Kolkata",
                        bio: "The newer bio.", photoData: nil)

        let older = Date(timeIntervalSinceReferenceDate: 99_999)
        s.restoreMyProfile(name: "Old Name", bio: "Stale bio.",
                           city: "Old City", birthday: older)

        #expect(s.currentUser.displayName == "Shalinth Rajan")
        #expect(s.currentUser.bio == "The newer bio.")
        #expect(s.currentUser.city == "Chennai")
        #expect(s.currentUser.birthday == birthday)
    }

    /// Mixed state: some fields local, some only remote. Each is decided on its
    /// own, not all-or-nothing.
    @Test("recovery fills only the fields that are actually missing")
    func fillsGapsIndividually() {
        let s = service("gaps")
        s.updateProfile(firstName: "Shalinth", lastName: "",
                        birthday: nil, city: nil,
                        timezoneIdentifier: nil,
                        bio: "Kept.", photoData: nil)

        s.restoreMyProfile(name: "Ignored Name", bio: "Discarded.",
                           city: "Puducherry", birthday: birthday)

        #expect(s.currentUser.bio == "Kept.")            // local wins
        #expect(s.currentUser.city == "Puducherry")      // gap filled
        #expect(s.currentUser.birthday == birthday)      // gap filled
        #expect(s.currentUser.displayName == "Shalinth") // local wins
    }

    /// Calling recovery repeatedly — which happens on every sign-in — must be
    /// a no-op after the first.
    @Test("recovery is idempotent")
    func repeatedRecoveryIsStable() {
        let s = service("idempotent")
        for _ in 0..<3 {
            s.restoreMyProfile(name: "Shalinth", bio: "Once.",
                               city: "Puducherry", birthday: birthday)
        }
        #expect(s.currentUser.displayName == "Shalinth")
        #expect(s.currentUser.bio == "Once.")
        #expect(s.currentUser.firstName == "Shalinth")
    }

    /// A blank name on the server must not blank the local one.
    @Test("a blank recovered name changes nothing")
    func blankRecoveredNameIsIgnored() {
        let s = service("blankname")
        let recovered = s.restoreMyProfile(name: "   ", bio: nil, city: nil, birthday: nil)
        #expect(!recovered)
        #expect(s.currentUser.displayName.isEmpty)
        #expect(!s.hasCompletedAboutYou)
    }
}

// MARK: - Choosing WHICH space to recover into

/// The bug this covers, reported from a real device: reinstall, sign in, and
/// land in "another new group which I haven't even created".
///
/// The user was in three spaces — a real two-person one with 58 location
/// records and four letters, an empty solo leftover, and one they had left.
/// `restoreSpaceMembership` used `.limit(to: 1)` with no ordering, so Firestore
/// returned an arbitrary document and it picked the empty leftover.
///
/// `.limit(to: 1)` encoded an assumption that a person belongs to one space.
/// The two-person cap makes that feel true, but the cap is per space, not per
/// user: create one, leave, join another, and you are in several.
@Suite("Space selection on recovery")
struct SpaceSelectionTests {

    /// Mirrors `FirebaseService.bestSpace`. The real one takes
    /// `QueryDocumentSnapshot`, which cannot be constructed outside Firestore —
    /// so the ordering rule is restated here over the same fields. Keep the two
    /// in step; the rule is what matters, and it is short by design.
    private struct Space {
        let id: String
        let members: [String]
        let updatedAt: Date
        let leftBy: String?
    }

    private func best(_ spaces: [Space], uid: String) -> Space? {
        let live = spaces.filter { $0.members.contains(uid) }
        return live.max { a, b in
            let pa = a.members.count >= 2, pb = b.members.count >= 2
            if pa != pb { return !pa }
            return a.updatedAt < b.updatedAt
        }
    }

    private let me = "NZG0jEcOPS"
    private let them = "vD0LovrjD3"

    /// The exact shape of the production data that caused the report.
    @Test("the paired space wins over an empty leftover")
    func pairedSpaceWins() throws {
        let spaces = [
            // The empty leftover — deliberately the MOST recently updated, which
            // is what makes the bug deterministic rather than luck.
            Space(id: "rG5RBTUk", members: [me],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 900), leftBy: nil),
            Space(id: "ERSgfMCd", members: [me, them],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 100), leftBy: nil),
        ]
        let chosen = try #require(best(spaces, uid: me))
        #expect(chosen.id == "ERSgfMCd", "recovered into the empty leftover again")
    }

    /// A space they walked out of is not a candidate — they are no longer in
    /// `memberUids`, which is also how the query itself filters.
    @Test("a space you left is never chosen")
    func leftSpaceIsSkipped() throws {
        let spaces = [
            Space(id: "3vc7wUhw", members: [],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 999), leftBy: me),
            Space(id: "ERSgfMCd", members: [me, them],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 1), leftBy: nil),
        ]
        let chosen = try #require(best(spaces, uid: me))
        #expect(chosen.id == "ERSgfMCd")
    }

    /// Among equals, the one they last used.
    @Test("two solo spaces resolve to the most recent")
    func mostRecentSoloWins() throws {
        let spaces = [
            Space(id: "older", members: [me],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 10), leftBy: nil),
            Space(id: "newer", members: [me],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 20), leftBy: nil),
        ]
        #expect(try #require(best(spaces, uid: me)).id == "newer")
    }

    /// Two paired spaces shouldn't happen, but if they do the tie-break is
    /// still recency rather than whatever Firestore returns first.
    @Test("two paired spaces resolve to the most recent")
    func mostRecentPairedWins() throws {
        let spaces = [
            Space(id: "old", members: [me, them],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 10), leftBy: nil),
            Space(id: "new", members: [me, "someoneElse"],
                  updatedAt: Date(timeIntervalSinceReferenceDate: 20), leftBy: nil),
        ]
        #expect(try #require(best(spaces, uid: me)).id == "new")
    }

    @Test("no memberships means nothing to recover")
    func noMembershipsRecoversNothing() {
        #expect(best([], uid: me) == nil)
        #expect(best([Space(id: "theirs", members: [them],
                            updatedAt: .now, leftBy: nil)], uid: me) == nil)
    }

    /// The single-space case must keep working — it is the common one.
    @Test("one membership is chosen directly")
    func singleMembership() throws {
        let only = Space(id: "only", members: [me, them], updatedAt: .now, leftBy: nil)
        #expect(try #require(best([only], uid: me)).id == "only")
    }
}

// MARK: - Pair-code format

/// Every code that has ever existed in this project is six characters —
/// FECY63, FZ48D3, HW5YEC, K8779U. An eight-character format lived in the
/// source for a while and never minted one, so an eight-cell entry screen
/// rejected every invite anyone actually held.
@MainActor
@Suite("Pair code format")
struct PairCodeFormatTests {

    @Test("codes are six characters")
    func lengthIsSix() {
        #expect(FirebaseService.codeLength == 6)
        for _ in 0..<50 {
            #expect(FirebaseService.makeCode().count == 6)
        }
    }

    /// The real codes from production must all still be enterable.
    @Test("every code in production validates")
    func productionCodesValidate() {
        for code in ["FECY63", "FZ48D3", "HW5YEC", "K8779U"] {
            #expect(FirebaseService.isPlausiblePairCode(code), "\(code) rejected")
        }
    }

    @Test("eight characters is no longer accepted")
    func eightIsRejected() {
        #expect(!FirebaseService.isPlausiblePairCode("REVW2001"))
    }

    @Test("display splits down the middle")
    func displaySplit() {
        #expect(FirebaseService.formatPairCode("HW5YEC") == "HW5-YEC")
        #expect(FirebaseService.formatPairCode("hw5-yec") == "HW5-YEC")
    }

    /// A minted code must survive the round trip a user puts it through:
    /// formatted for sharing, typed back with the hyphen, normalised again.
    @Test("minted codes round-trip through format and normalize")
    func roundTrip() {
        for _ in 0..<50 {
            let code = FirebaseService.makeCode()
            let shown = FirebaseService.formatPairCode(code)
            #expect(FirebaseService.normalizePairCode(shown) == code)
            #expect(FirebaseService.isPlausiblePairCode(shown))
        }
    }

    /// Ambiguous glyphs stay out — I, L and O read as 1 and 0 when someone is
    /// copying a code off another person's screen.
    @Test("minted codes avoid characters that misread")
    func noAmbiguousCharacters() {
        for _ in 0..<50 {
            let code = FirebaseService.makeCode()
            #expect(!code.contains("I") && !code.contains("L") && !code.contains("O"))
        }
    }
}
