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

    private let cloud: CloudKitService
    private let setupKey = "tweli.roomSetupComplete"
    private let defaults = UserDefaults.standard

    init(cloud: CloudKitService) {
        self.cloud = cloud
        self.currentUser = MockData.shalinth
        // Only enter the app if the user has already created/joined a space.
        if defaults.bool(forKey: setupKey) {
            self.coupleSpace = MockData.coupleSpace
            self.partner = MockData.anaya
        } else {
            self.coupleSpace = nil
            self.partner = nil
        }
    }

    var isConnected: Bool { coupleSpace != nil }

    /// Updates the signed-in user's display name (from AuthService).
    func setDisplayName(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        currentUser.displayName = name
    }

    /// Create a brand-new couple space (owner). No partner yet — the space waits
    /// for the invited person to accept the share (see `setPartnerJoined`).
    func createSpace(title: String) {
        let space = CoupleSpace(title: title.isEmpty ? "Our Space" : title,
                                createdBy: currentUser.id, partnerIds: [currentUser.id])
        coupleSpace = space
        partner = nil
        completeSetup()
        Task { await cloud.createCoupleSpace(space) }
    }

    /// Connect after accepting a partner's CloudKit share (participant role). The
    /// partner is the person who created & shared the space (from their identity).
    func connectAsParticipant(title: String, partnerName: String) {
        coupleSpace = CoupleSpace(title: title, createdBy: UUID(), partnerIds: [currentUser.id])
        partner = UserProfile(displayName: partnerName, avatarEmoji: "💛")
        completeSetup()
    }

    /// Owner side: called once CloudKit reports the invited person has accepted.
    func setPartnerJoined(name: String) {
        guard partner == nil else { return }
        partner = UserProfile(displayName: name, avatarEmoji: "💛")
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
    }
}
