//
//  AppViewModel.swift
//  Tweli
//
//  Composition root. Owns every service, wires their `onDataChanged` hooks to
//  the widget snapshot, stamps the current-user identity, and holds app-level
//  UI state (which Home direction is showing). Injected as an @EnvironmentObject.
//

import SwiftUI
import Combine

/// The two Home dashboard directions from the design (toggle in the Home header).
enum HomeStyle: String, CaseIterable, Identifiable {
    case overview   // 1a — data-forward
    case moment     // 1b — one feeling at a time
    var id: String { rawValue }
    var label: String { self == .overview ? "Overview" : "Moment" }
    var sfSymbol: String { self == .overview ? "square.grid.2x2.fill" : "heart.text.square.fill" }
}

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - App-level UI state
    @Published var homeStyle: HomeStyle = .overview
    @Published var showSplash: Bool = true

    // MARK: - Services (shared graph)
    let auth = AuthService()
    let cloud = CloudKitService()
    let notifications = ReminderNotificationService()
    let widget = WidgetDataService()

    let coupleSpaceService: CoupleSpaceService
    let reminderService: ReminderService
    let countdownService: CountdownService
    let virtualDateService: VirtualDateService
    let letterService: OpenWhenLetterService
    let moodService: MoodService
    let missingYouService: MissingYouService

    init() {
        coupleSpaceService = CoupleSpaceService(cloud: cloud)
        reminderService = ReminderService(notifications: notifications, cloud: cloud)
        countdownService = CountdownService(cloud: cloud, notifications: notifications)
        virtualDateService = VirtualDateService(cloud: cloud, notifications: notifications)
        letterService = OpenWhenLetterService(cloud: cloud)
        moodService = MoodService(cloud: cloud)
        missingYouService = MissingYouService(cloud: cloud)

        wireIdentities()
        wireWidgetRefresh()
        refreshWidget()
    }

    // MARK: - Convenience

    var isConnected: Bool { coupleSpaceService.isConnected }
    var currentUser: UserProfile { coupleSpaceService.currentUser }
    var partner: UserProfile? { coupleSpaceService.partner }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    // MARK: - Wiring

    private func wireIdentities() {
        if auth.isSignedIn { coupleSpaceService.setDisplayName(auth.displayName) }
        let meId = coupleSpaceService.currentUser.id
        let partnerId = coupleSpaceService.partner?.id ?? MockData.anayaId
        reminderService.currentUserId = meId
        moodService.currentUserId = meId
        moodService.partnerId = partnerId
        missingYouService.currentUserId = meId
        missingYouService.partnerId = partnerId
        if let spaceId = coupleSpaceService.coupleSpace?.id {
            missingYouService.coupleSpaceId = spaceId
        }
    }

    private func wireWidgetRefresh() {
        let refresh: () -> Void = { [weak self] in self?.refreshWidget() }
        reminderService.onDataChanged = refresh
        countdownService.onDataChanged = refresh
        virtualDateService.onDataChanged = refresh
        letterService.onDataChanged = refresh
        moodService.onDataChanged = refresh
        missingYouService.onDataChanged = refresh
    }

    /// Assemble the "at a glance" widget snapshot from the current data.
    func refreshWidget() {
        let cd = countdownService.pinned
        let mood = moodService.partnerMood
        let date = virtualDateService.next
        let ping = missingYouService.history.first
        let pingFrom = ping.map {
            $0.sentBy == currentUser.id ? "You" : (coupleSpaceService.partner?.displayName ?? "Partner")
        } ?? "—"
        let snapshot = WidgetSnapshot(
            daysUntil: cd?.daysRemaining ?? 0,
            countdownTitle: cd?.title ?? "No countdown yet",
            partnerName: coupleSpaceService.partner?.displayName ?? "Partner",
            partnerMood: mood?.mood.label ?? "—",
            partnerMoodEmoji: mood?.mood.emoji ?? "💗",
            nextDateTitle: date?.title ?? "No date planned",
            nextDateTime: date.map { $0.date.formatted(date: .omitted, time: .shortened) } ?? "—",
            lastPingMessage: ping?.message ?? "Send a little love",
            lastPingFrom: pingFrom,
            lastPingWhen: ping?.relativeLabel ?? ""
        )
        widget.update(snapshot)
    }

    // MARK: - Notification bootstrap (runs exactly once)

    private var didBootstrap = false

    /// Schedules all reminder + countdown notifications once at startup. Kept OUT
    /// of init because `@StateObject var app = AppViewModel()` evaluates the
    /// initializer eagerly on every App/View creation — side effects in init would
    /// schedule duplicates. Call this from a `.task` instead.
    func bootstrapNotifications() {
        guard !didBootstrap else { return }
        didBootstrap = true
        notifications.removeAllPending()   // clear stale (mock ids change per launch)
        reminderService.scheduleAll()
        countdownService.scheduleAll()
    }

    // MARK: - Notification permission

    func requestNotificationPermission() {
        Task { await notifications.requestAuthorization() }
    }
}
