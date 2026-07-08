//
//  CoupleSpace.swift
//  Tweli
//

import Foundation

/// The private shared space that connects two partners.
/// `partnerIds` holds the `UserProfile` ids of both people once connected.
struct CoupleSpace: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var createdBy: UUID
    var partnerIds: [UUID]
    var createdAt: Date = Date()

    /// Short token embedded in the invite link (CloudKit CKShare URL later).
    var inviteCode: String = String(UUID().uuidString.prefix(6)).uppercased()

    /// The shareable invite link a partner opens/pastes to join this space.
    var inviteLink: String { "https://tweli.app/join/\(inviteCode)" }
}
