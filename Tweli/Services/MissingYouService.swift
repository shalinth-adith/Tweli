//
//  MissingYouService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class MissingYouService: ObservableObject {

    @Published private(set) var pings: [MissingYouPing]

    var currentUserId = UUID()   // set by AppViewModel.wireIdentities()
    var partnerId = UUID()
    var coupleSpaceId = UUID()
    var onDataChanged: (() -> Void)?
    private let cloud: CloudKitService

    init(cloud: CloudKitService) {
        self.cloud = cloud
#if DEBUG
        self.pings = MockData.pings   // demo data for design/dev builds only
#else
        self.pings = []
#endif
    }

    /// Most recent first, for the history list.
    var history: [MissingYouPing] { pings.sorted { $0.sentAt > $1.sentAt } }

    func send(_ preset: MissingYouPreset, senderName: String) {
        let ping = MissingYouPing(
            message: preset.message(from: senderName),
            sentBy: currentUserId,
            sentTo: partnerId,
            coupleSpaceId: coupleSpaceId
        )
        pings.insert(ping, at: 0)
        // TODO: CloudKit — sync + deliver a notification to the partner's device.
        Task { await cloud.sendPing(ping) }
        onDataChanged?()
    }

    func mergeRemote(_ items: [MissingYouPing], deletedIDs: [UUID]) {
        for item in items where !pings.contains(where: { $0.id == item.id }) {
            pings.append(item)
        }
        if !deletedIDs.isEmpty { pings.removeAll { deletedIDs.contains($0.id) } }
    }
}
