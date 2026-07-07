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

    init(cloud: CloudKitService) {
        self.cloud = cloud
        // Mock-first: pre-connected space so the app runs on realistic data.
        self.currentUser = MockData.shalinth
        self.partner = MockData.anaya
        self.coupleSpace = MockData.coupleSpace
    }

    var isConnected: Bool { coupleSpace != nil }

    /// Create a brand-new couple space (used by onboarding "Create Partner Space").
    func createSpace(title: String, myName: String) {
        var me = currentUser
        me.displayName = myName.isEmpty ? "You" : myName
        currentUser = me
        let space = CoupleSpace(title: title.isEmpty ? "Our Space" : title,
                                createdBy: me.id, partnerIds: [me.id])
        coupleSpace = space
        Task { await cloud.createCoupleSpace(space) }
    }

    /// Join an existing space from an invite code (placeholder until CloudKit sharing).
    func joinSpace(code: String, myName: String) async {
        var me = currentUser
        me.displayName = myName.isEmpty ? "You" : myName
        currentUser = me
        if let joined = await cloud.joinCoupleSpace(code: code) {
            coupleSpace = joined
        } else {
            // TODO: CloudKit — real join. For now, mock a connected space.
            coupleSpace = MockData.coupleSpace
            partner = MockData.anaya
        }
    }

    /// Reset (used by Settings "disconnect") — returns to onboarding.
    func disconnect() {
        coupleSpace = nil
        partner = nil
    }
}
