//
//  SharedLocation.swift
//  Tweli
//
//  One partner's shared location — used to show how far apart the two of you are.
//  Like MoodStatus, there is exactly one record per user (each person writes only
//  their own); the distance is computed on-device from both. Coordinates are
//  coarse (city-level), captured opt-in — see LocationService.
//

import Foundation

struct SharedLocation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var userId: UUID
    var latitude: Double
    var longitude: Double
    /// Reverse-geocoded place name for display, e.g. "Austin, TX". Optional.
    var cityLabel: String? = nil
    var updatedAt: Date = Date()
}
