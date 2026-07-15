//
//  VirtualDateService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class VirtualDateService: ObservableObject {

    @Published private(set) var dates: [VirtualDateItem]

    var onDataChanged: (() -> Void)?
    private let cloud: FirebaseService
    private let notifications: ReminderNotificationService

    init(cloud: FirebaseService, notifications: ReminderNotificationService) {
        self.cloud = cloud
        self.notifications = notifications
        self.dates = []
#if DEBUG
        if AppEnvironment.useDemoData { self.dates = MockData.virtualDates }
#endif
    }

    /// The next planned date — Home dashboard + widget.
    var next: VirtualDateItem? {
        dates.filter { $0.status == .planned && $0.date >= Date() }
            .min { $0.date < $1.date }
    }

    var planned: [VirtualDateItem] {
        dates.filter { $0.status == .planned }.sorted { $0.date < $1.date }
    }

    func add(_ date: VirtualDateItem) {
        dates.append(date)
        if date.reminderEnabled { scheduleReminder(for: date) }
        Task { await cloud.saveVirtualDate(date) }
        onDataChanged?()
    }

    func update(_ date: VirtualDateItem) {
        guard let i = dates.firstIndex(where: { $0.id == date.id }) else { return }
        dates[i] = date
        Task { await cloud.saveVirtualDate(date) }
        onDataChanged?()
    }

    func setStatus(_ date: VirtualDateItem, _ status: VirtualDateStatus) {
        guard let i = dates.firstIndex(where: { $0.id == date.id }) else { return }
        dates[i].status = status
        onDataChanged?()
    }

    func delete(_ date: VirtualDateItem) {
        dates.removeAll { $0.id == date.id }
        Task { await cloud.saveVirtualDate(date) }
        onDataChanged?()
    }

    func mergeRemote(_ items: [VirtualDateItem], deletedIDs: [UUID]) {
        for item in items {
            if let i = dates.firstIndex(where: { $0.id == item.id }) { dates[i] = item }
            else { dates.append(item) }
        }
        if !deletedIDs.isEmpty { dates.removeAll { deletedIDs.contains($0.id) } }
    }

    private func scheduleReminder(for date: VirtualDateItem) {
        // Nudge 30 minutes before the date.
        let fireDate = date.date.addingTimeInterval(-30 * 60)
        guard fireDate > Date() else { return }
        notifications.scheduleOneOff(
            id: "vdate-\(date.id.uuidString)",
            title: "\(date.title) soon 💕",
            body: "Your virtual date starts in 30 minutes.",
            at: fireDate
        )
    }
}
