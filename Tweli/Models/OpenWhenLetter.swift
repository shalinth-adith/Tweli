//
//  OpenWhenLetter.swift
//  Tweli
//

import Foundation

/// A digital "open when…" letter for long-distance moments.
struct OpenWhenLetter: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var message: String
    var createdBy: UUID
    var coupleSpaceId: UUID
    var unlockDate: Date? = nil
    var isOpened: Bool = false
    var openedAt: Date? = nil
    var createdAt: Date = Date()

    /// A letter with a future `unlockDate` is still sealed.
    var isLocked: Bool {
        guard let unlockDate else { return false }
        return unlockDate > Date()
    }
}
