//
//  PendingInvite.swift
//  Tweli
//
//  A CloudKit share invite the partner just opened, waiting for confirmation.
//  Wraps CKShare.Metadata and derives friendly display strings (the space name
//  and who sent it) for the "confirm join" sheet.
//

import Foundation
import CloudKit

struct PendingInvite: Identifiable {
    let metadata: CKShare.Metadata

    var id: String { metadata.share.recordID.recordName }

    /// The plain space name, recovered from the share title we set at creation
    /// ("Join <name> on Tweli 💞"). Falls back gracefully if the format differs.
    var spaceTitle: String {
        let raw = (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? ""
        var name = raw
        if name.hasPrefix("Join ") { name.removeFirst("Join ".count) }
        if let range = name.range(of: " on Tweli") { name = String(name[..<range.lowerBound]) }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "your shared space" : trimmed
    }

    /// The inviter's name from their iCloud identity, if shared.
    var inviterName: String {
        if let comps = metadata.ownerIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter.localizedString(from: comps, style: .default)
            if !formatted.isEmpty { return formatted }
        }
        return "Your partner"
    }
}
