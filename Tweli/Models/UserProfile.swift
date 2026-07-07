//
//  UserProfile.swift
//  Tweli
//

import Foundation

/// A single person in the couple. `iCloudUserId` is filled once CloudKit is wired.
struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var avatarEmoji: String
    var iCloudUserId: String? = nil          // TODO: CloudKit — CKRecord.ID.recordName
    var createdAt: Date = Date()

    /// Initials used for the round avatar chips in the design.
    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
