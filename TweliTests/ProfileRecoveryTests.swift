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
