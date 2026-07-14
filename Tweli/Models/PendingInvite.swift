//
//  PendingInvite.swift
//  Tweli
//
//  An invite the partner just redeemed, waiting for confirmation. A plain struct
//  built from the Firestore pair-code / space documents (via FirebaseService's
//  PairInvite) — no CloudKit share metadata, no share-title parsing.
//

import Foundation

struct PendingInvite: Identifiable {
    let spaceId: String
    let spaceTitle: String
    let inviterName: String

    var id: String { spaceId }

    /// Build from a redeemed pair code, preserving the load-bearing non-empty
    /// fallbacks the confirm sheet relies on for the degraded case (inviter has no
    /// display name yet, blank space title).
    init(invite: FirebaseService.PairInvite) {
        spaceId = invite.spaceId
        let title = invite.spaceTitle.trimmingCharacters(in: .whitespaces)
        spaceTitle = title.isEmpty ? "your shared space" : title
        let name = invite.inviterName.trimmingCharacters(in: .whitespaces)
        inviterName = name.isEmpty ? "Your partner" : name
    }
}
