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

    /// Human-friendly invite code prepared for the connect flow (CloudKit sharing later).
    var inviteCode: String = String(UUID().uuidString.prefix(6)).uppercased()
}
