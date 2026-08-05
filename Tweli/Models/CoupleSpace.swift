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

    // NOTE: this model deliberately carries NO invite code. The code that
    // actually redeems lives in Firestore at `pairCodes/{code}` and is surfaced
    // by `FirebaseService.activePairCode`. A locally-generated one used to live
    // here and was shown to users — it was never published, so nobody could
    // ever join with it.
}
