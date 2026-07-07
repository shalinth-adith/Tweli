//
//  CountdownService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class CountdownService: ObservableObject {

    @Published private(set) var countdowns: [CountdownItem]

    var onDataChanged: (() -> Void)?
    private let cloud: CloudKitService

    init(cloud: CloudKitService) {
        self.cloud = cloud
        self.countdowns = MockData.countdowns
    }

    /// The pinned (or soonest) countdown shown as the Home hero + widget.
    var pinned: CountdownItem? {
        countdowns.first { $0.isPinned } ?? countdowns.min { $0.daysRemaining < $1.daysRemaining }
    }

    var upcoming: [CountdownItem] {
        countdowns.sorted { $0.daysRemaining < $1.daysRemaining }
    }

    func add(_ countdown: CountdownItem) {
        countdowns.append(countdown)
        Task { await cloud.saveCountdown(countdown) }
        onDataChanged?()
    }

    func update(_ countdown: CountdownItem) {
        guard let i = countdowns.firstIndex(where: { $0.id == countdown.id }) else { return }
        countdowns[i] = countdown
        Task { await cloud.saveCountdown(countdown) }
        onDataChanged?()
    }

    func delete(_ countdown: CountdownItem) {
        countdowns.removeAll { $0.id == countdown.id }
        Task { await cloud.deleteCountdown(countdown) }
        onDataChanged?()
    }

    func togglePin(_ countdown: CountdownItem) {
        for i in countdowns.indices { countdowns[i].isPinned = false }
        if let i = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[i].isPinned.toggle()
        }
        onDataChanged?()
    }
}
