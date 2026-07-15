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
    private let cloud: FirebaseService
    private let notifications: ReminderNotificationService

    init(cloud: FirebaseService, notifications: ReminderNotificationService) {
        self.cloud = cloud
        self.notifications = notifications
        self.countdowns = []
#if DEBUG
        if AppEnvironment.useDemoData { self.countdowns = MockData.countdowns }
#endif
    }

    /// Schedule "the day is here" alerts for all current countdowns. Called once
    /// at startup (NOT from init — see AppViewModel bootstrap).
    func scheduleAll() {
        for c in countdowns { notifications.scheduleCountdown(c) }
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
        notifications.scheduleCountdown(countdown)
        Task { await cloud.saveCountdown(countdown) }
        onDataChanged?()
    }

    func update(_ countdown: CountdownItem) {
        guard let i = countdowns.firstIndex(where: { $0.id == countdown.id }) else { return }
        countdowns[i] = countdown
        notifications.rescheduleCountdown(countdown)
        Task { await cloud.saveCountdown(countdown) }
        onDataChanged?()
    }

    func delete(_ countdown: CountdownItem) {
        countdowns.removeAll { $0.id == countdown.id }
        notifications.cancelCountdown(id: countdown.id)
        Task { await cloud.deleteCountdown(countdown) }
        onDataChanged?()
    }

    func mergeRemote(_ items: [CountdownItem], deletedIDs: [UUID]) {
        for item in items {
            if let i = countdowns.firstIndex(where: { $0.id == item.id }) { countdowns[i] = item }
            else { countdowns.append(item) }
            // Same fix as ReminderService.mergeRemote: remote countdowns must
            // schedule their day-zero notification on this device immediately.
            notifications.rescheduleCountdown(item)
        }
        for id in deletedIDs where countdowns.contains(where: { $0.id == id }) {
            notifications.cancelCountdown(id: id)
        }
        if !deletedIDs.isEmpty { countdowns.removeAll { deletedIDs.contains($0.id) } }
    }

    func togglePin(_ countdown: CountdownItem) {
        for i in countdowns.indices { countdowns[i].isPinned = false }
        if let i = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[i].isPinned.toggle()
        }
        onDataChanged?()
    }
}
