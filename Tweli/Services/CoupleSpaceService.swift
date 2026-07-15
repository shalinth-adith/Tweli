//
//  CoupleSpaceService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class CoupleSpaceService: ObservableObject {

    @Published private(set) var coupleSpace: CoupleSpace?
    @Published private(set) var currentUser: UserProfile
    @Published private(set) var partner: UserProfile?

    /// True once the user has finished (or skipped) the "About you" screen. Drives
    /// the first-run bio step in RootView.
    @Published private(set) var hasCompletedAboutYou: Bool

    private let cloud: FirebaseService
    private let setupKey = "tweli.roomSetupComplete"
    private let userKey = "tweli.currentUser"
    private let spaceKey = "tweli.coupleSpace"
    private let partnerKey = "tweli.partner"
    private let aboutYouKey = "tweli.aboutYouDone"
    private let defaults = UserDefaults.standard

    init(cloud: FirebaseService) {
        self.cloud = cloud
        self.hasCompletedAboutYou = defaults.bool(forKey: aboutYouKey)

        // Real, persisted identity — created once per install, name filled from
        // the Apple account on sign in. Mock only seeds design/dev builds.
        if let saved = Self.load(UserProfile.self, userKey, defaults) {
            self.currentUser = saved
        } else {
            var seeded = UserProfile(displayName: "", avatarEmoji: "💛")
#if DEBUG
            if AppEnvironment.useDemoData { seeded = MockData.shalinth }
#endif
            self.currentUser = seeded
        }

        // Restore the real space + partner if setup was completed on this device.
        if defaults.bool(forKey: setupKey) {
            var space = Self.load(CoupleSpace.self, spaceKey, defaults)
            var restoredPartner = Self.load(UserProfile.self, partnerKey, defaults)
#if DEBUG
            if AppEnvironment.useDemoData {
                if space == nil { space = MockData.coupleSpace }
                if restoredPartner == nil { restoredPartner = MockData.anaya }
            }
#endif
            self.coupleSpace = space
            self.partner = restoredPartner
        } else {
            self.coupleSpace = nil
            self.partner = nil
        }

        save(currentUser, userKey)   // persist a freshly-generated identity
    }

    var isConnected: Bool { coupleSpace != nil }

    /// Updates the signed-in user's display name (from AuthService) and persists it.
    func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        currentUser.displayName = trimmed
        save(currentUser, userKey)
    }

    /// Seed the name from the Apple account, but NEVER overwrite a name the user
    /// has already set (e.g. edited on the "About you" screen). Apple only returns
    /// a name on first authorization, so this is a one-time seed, not the source
    /// of truth — `currentUser.displayName` is.
    func seedDisplayName(_ name: String) {
        guard currentUser.displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        setDisplayName(name)
    }

    /// Save the "About you" details onto the current user's profile (design 20a/b).
    /// Persisted locally; the name still flows to the partner via `memberNames`.
    func updateProfile(name: String, birthday: Date?, city: String?,
                       timezoneIdentifier: String?, photoData: Data?) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { currentUser.displayName = trimmed }
        currentUser.birthday = birthday
        currentUser.city = city?.trimmingCharacters(in: .whitespaces)
        currentUser.timezoneIdentifier = timezoneIdentifier
        currentUser.photoData = photoData
        save(currentUser, userKey)
    }

    /// Mark the first-run "About you" step finished (completed or skipped).
    func completeAboutYou() {
        defaults.set(true, forKey: aboutYouKey)
        hasCompletedAboutYou = true
    }

    // MARK: - Persistence

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Create a brand-new couple space (owner). No partner yet — the space waits
    /// for the invited person to accept the share (see `setPartnerJoined`).
    func createSpace(title: String) {
        let space = CoupleSpace(title: title.isEmpty ? "Our Space" : title,
                                createdBy: currentUser.id, partnerIds: [currentUser.id])
        coupleSpace = space
        partner = nil
        save(space, spaceKey)
        save(UserProfile?.none, partnerKey)
        completeSetup()
        Task { await cloud.createCoupleSpace(space) }
    }

    /// Connect after accepting a partner's CloudKit share (participant role). The
    /// partner is the person who created & shared the space (from their identity).
    func connectAsParticipant(title: String, partnerName: String) {
        let space = CoupleSpace(title: title, createdBy: UUID(), partnerIds: [currentUser.id])
        coupleSpace = space
        partner = UserProfile(displayName: partnerName, avatarEmoji: "💛")
        save(space, spaceKey)
        save(partner, partnerKey)
        completeSetup()
    }

    /// Owner side: called once CloudKit reports the invited person has accepted.
    func setPartnerJoined(name: String) {
        guard partner == nil else { return }
        partner = UserProfile(displayName: name, avatarEmoji: "💛")
        save(partner, partnerKey)
    }

    /// True while the owner is connected but nobody has accepted the invite yet.
    var awaitingPartner: Bool { coupleSpace != nil && partner == nil }

    private func completeSetup() {
        defaults.set(true, forKey: setupKey)
    }

    /// Reset (Settings "sign out" / "leave space") — returns to room setup.
    func disconnect() {
        defaults.set(false, forKey: setupKey)
        coupleSpace = nil
        partner = nil
        save(CoupleSpace?.none, spaceKey)
        save(UserProfile?.none, partnerKey)
    }
}
