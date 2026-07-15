//
//  UserProfile.swift
//  Tweli
//

import Foundation

/// A single person in the couple. Identity is the Firebase UID (stored on the
/// space's member maps); this local profile carries the "About you" details
/// collected on first sign-in.
struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var avatarEmoji: String
    var createdAt: Date = Date()

    // MARK: - About you (design 20a/b)

    /// The person's birthday (day the partner is reminded about). Optional —
    /// collected on the "About you" screen, editable later in Settings.
    var birthday: Date? = nil
    /// Free-text city, shown to the partner alongside the local time.
    var city: String? = nil
    /// IANA timezone identifier (e.g. "Asia/Kolkata"), defaulted from the device
    /// so the partner always sees the right local time.
    var timezoneIdentifier: String? = nil
    /// Locally-stored, compressed avatar photo (JPEG data). Not yet synced to the
    /// partner — that needs Firebase Storage / a doc field (see follow-up).
    var photoData: Data? = nil

    /// Initials used for the round avatar chips in the design.
    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    /// The person's current local time zone, or the device's as a fallback.
    var timeZone: TimeZone {
        timezoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
    }
}
