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

    /// A fresh invite link to show on the Create screen before the space exists.
    func makeDraftInviteLink() -> String {
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        return "https://tweli.app/join/\(code)"
    }

    /// Create a brand-new couple space and finish room setup.
    /// Mock: the partner (Anaya) is connected so the app is fully populated;
    /// with CloudKit the space would wait for a real join via the invite link.
    func createSpace(title: String) {
        let space = CoupleSpace(title: title.isEmpty ? "Our Space" : title,
                                createdBy: currentUser.id, partnerIds: [currentUser.id])
        coupleSpace = space
        partner = MockData.anaya
        completeSetup()
        Task { await cloud.createCoupleSpace(space) }
    }

    /// Join an existing space from an invite link.
    func joinSpace(link: String) async {
        let code = Self.inviteCode(from: link)
        if let joined = await cloud.joinCoupleSpace(code: code) {
            coupleSpace = joined
        } else {
            // TODO: CloudKit — real join. For now, mock a connected space.
            coupleSpace = MockData.coupleSpace
            partner = MockData.anaya
        }
        completeSetup()
    }

    /// Extracts the invite token from a pasted link or bare code.
    static func inviteCode(from link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.split(whereSeparator: { $0 == "/" }).last { return String(last) }
        return trimmed
    }

    /// A pasted string looks like a valid invite (link or code) once it has a token.
    static func isValidInvite(_ link: String) -> Bool {
        !inviteCode(from: link).isEmpty && link.count >= 4
    }

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
