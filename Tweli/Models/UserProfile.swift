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

    // MARK: - Structured name + bio (comps X1, X2, X5)

    /// Given name, collected on X1. `displayName` stays the authoritative,
    /// cloud-visible string — these two are the structured source it is composed
    /// from, kept so the flow can edit each part on its own page.
    var firstName: String = ""
    /// Family name, collected on X2. Optional by design: the comp's own copy
    /// says "skip it and keep going".
    var lastName: String = ""
    /// One line the partner sees on your profile (X5). Capped at 120 characters
    /// by the composer; `nil` until the person writes one.
    var bio: String? = nil

    /// `firstName`/`lastName` joined, falling back to whatever `displayName`
    /// already held. Profiles created before X1–X6 have empty name parts and a
    /// populated `displayName`, so this keeps reading correctly for them.
    var composedName: String {
        let parts = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? displayName : parts.joined(separator: " ")
    }

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
