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
    /// AuthService's persisted-name key. FirebaseService reads THIS key when writing
    /// `memberNames` / pair-code `createdByName`, so profile-name edits must land
    /// here too — otherwise the partner sees the stale Apple-name fallback ("You").
    private let authNameKey = "tweli.auth.displayName"
    private let defaults = UserDefaults.standard

    init(cloud: FirebaseService) {
        self.cloud = cloud
        self.hasCompletedAboutYou = defaults.bool(forKey: aboutYouKey)

        // Real, persisted identity — created once per install, name filled from
        // the Apple account on sign in. Mock only seeds design/dev builds.
        if let saved = Self.load(UserProfile.self, userKey, defaults) {
            self.currentUser = saved
        } else {
            self.currentUser = UserProfile(displayName: "", avatarEmoji: "💛")
        }

        // Restore the real space + partner if setup was completed on this device.
        if defaults.bool(forKey: setupKey) {
            self.coupleSpace = Self.load(CoupleSpace.self, spaceKey, defaults)
            self.partner = Self.load(UserProfile.self, partnerKey, defaults)
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
        defaults.set(trimmed, forKey: authNameKey)   // keep the cloud-visible name in sync
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
        if !trimmed.isEmpty {
            currentUser.displayName = trimmed
            defaults.set(trimmed, forKey: authNameKey)   // keep the cloud-visible name in sync
            // Keep the structured parts coherent with the single-field editor.
            // Without this, renaming here leaves the X1/X2 values stale and
            // `composedName` would keep returning the old name.
            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            currentUser.firstName = parts.first ?? ""
            currentUser.lastName = parts.count > 1 ? parts[1] : ""
        }
        currentUser.birthday = birthday
        currentUser.city = city?.trimmingCharacters(in: .whitespaces)
        currentUser.timezoneIdentifier = timezoneIdentifier
        currentUser.photoData = photoData
        save(currentUser, userKey)
    }

    /// Save the profile collected by the X1–X6 flow, which asks for the name in
    /// two parts and adds a bio. `displayName` is still what the partner sees via
    /// `memberNames`, so it is composed here and kept as the single cloud-visible
    /// string — nothing downstream has to learn about the split.
    func updateProfile(firstName: String, lastName: String, birthday: Date?,
                       city: String?, timezoneIdentifier: String?,
                       bio: String?, photoData: Data?) {
        currentUser.firstName = firstName.trimmingCharacters(in: .whitespaces)
        currentUser.lastName  = lastName.trimmingCharacters(in: .whitespaces)

        let composed = currentUser.composedName.trimmingCharacters(in: .whitespaces)
        if !composed.isEmpty {
            currentUser.displayName = composed
            defaults.set(composed, forKey: authNameKey)
        }

        currentUser.birthday = birthday
        currentUser.city = city?.trimmingCharacters(in: .whitespaces)
        currentUser.timezoneIdentifier = timezoneIdentifier
        let trimmedBio = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentUser.bio = (trimmedBio?.isEmpty ?? true) ? nil : trimmedBio
        currentUser.photoData = photoData
        save(currentUser, userKey)
    }

    /// Apply the partner's synced profile fields (comps X4–X6). Called on every
    /// space snapshot, so it must be idempotent and must not clobber a value with
    /// nil just because one field happened to be absent from this update.
    ///
    /// A `nil` here means "not present in the space doc", which is also how a
    /// cleared field arrives (the writer deletes the key). Both cases should show
    /// nothing, so nil genuinely does mean clear.
    func updatePartnerDetails(bio: String?, city: String?, birthday: Date?) {
        guard var p = partner else { return }
        guard p.bio != bio || p.city != city || p.birthday != birthday else { return }
        p.bio = bio
        p.city = city
        p.birthday = birthday
        partner = p
        save(partner, partnerKey)
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

    /// Rebuild local couple state from a space recovered by membership (fresh
    /// install / new device / sign-out and back in). Mirrors the join path's
    /// reconstruction — a local CoupleSpace plus a partner derived from the
    /// space doc's `memberNames` — and marks setup complete so RootView routes
    /// to the space instead of Start-or-join.
    func restoreFromRecoveredSpace(title: String, isOwner: Bool, partnerName: String?) {
        let space = CoupleSpace(title: title,
                                createdBy: isOwner ? currentUser.id : UUID(),
                                partnerIds: [currentUser.id])
        coupleSpace = space
        // A name only exists once both members are in the space; without one we
        // stay in the "waiting for partner" state rather than inventing them.
        partner = partnerName.flatMap { name in
            name.isEmpty ? nil : UserProfile(displayName: name, avatarEmoji: "💛")
        }
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

    /// Reflect the partner's current name from the space doc's `memberNames`.
    /// Creates the partner on first sight (owner side) and RENAMES on change —
    /// e.g. when the partner fixes their profile name after pairing, or when the
    /// join-time snapshot only had the "You" placeholder.
    func updatePartnerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if partner == nil {
            setPartnerJoined(name: trimmed)
        } else if partner?.displayName != trimmed {
            partner?.displayName = trimmed
            save(partner, partnerKey)
        }
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
