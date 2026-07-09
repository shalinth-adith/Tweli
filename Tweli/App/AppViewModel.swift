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
import CloudKit

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - App-level UI state
    @Published var showSplash: Bool = true

    /// Set when the partner opens an invite link — drives the "confirm join" sheet.
    /// The share is only accepted once the user taps Join (see `confirmPendingJoin`).
    @Published var pendingInvite: PendingInvite?

    /// Sentinel partner id used before anyone has joined — matches no real record.
    static let noPartnerId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private var cancellables = Set<AnyCancellable>()

    /// Deep-link targets (widget "Send love" → Moods tab, focus the message field).
    @Published var requestedTab: Int?
    @Published var focusMoodMessage = false

    /// Handle a tweli:// deep link opened from a widget.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "tweli" else { return }
        switch url.host {
        case "sendlove", "mood":
            requestedTab = 3            // Moods tab
            focusMoodMessage = true
        default:
            break
        }
    }

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

        // When the user signs in with Apple, apply their real name + re-wire ids.
        auth.$isSignedIn
            .sink { [weak self] signedIn in
                guard let self, signedIn else { return }
                self.coupleSpaceService.setDisplayName(self.auth.displayName)
                self.wireIdentities()
            }
            .store(in: &cancellables)
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
        // No partner yet → a sentinel id that matches no real record (empty data).
        let partnerId = coupleSpaceService.partner?.id ?? Self.noPartnerId
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
            partnerMoodNote: mood?.note ?? "",
            countdownProgress: cd?.progress ?? 0,
            userInitial: currentUser.initials,
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

    // MARK: - CloudKit sync

    /// Pull remote changes into the local services and register for push.
    /// Offline-first: the local store stays authoritative if CloudKit is off.
    func syncNow() {
        Task {
            await cloud.refreshAccountStatus()
            guard cloud.role != .none else { return }
            let changes = await cloud.fetchChanges()
            let dec = JSONDecoder()
            func decode<T: Decodable>(_ type: String) -> [T] {
                (changes.payloadsByType[type] ?? []).compactMap { try? dec.decode(T.self, from: $0) }
            }
            reminderService.mergeRemote(decode(CloudKitService.RType.reminder), deletedIDs: changes.deletedIDs)
            countdownService.mergeRemote(decode(CloudKitService.RType.countdown), deletedIDs: changes.deletedIDs)
            letterService.mergeRemote(decode(CloudKitService.RType.letter), deletedIDs: changes.deletedIDs)
            virtualDateService.mergeRemote(decode(CloudKitService.RType.virtualDate), deletedIDs: changes.deletedIDs)
            moodService.mergeRemote(decode(CloudKitService.RType.mood), deletedIDs: changes.deletedIDs)
            missingYouService.mergeRemote(decode(CloudKitService.RType.ping), deletedIDs: changes.deletedIDs)
            await cloud.registerSubscription()
            // Owner side: reflect it once the invited person accepts the share.
            if cloud.role == .owner, coupleSpaceService.awaitingPartner,
               let name = await cloud.acceptedParticipantName() {
                coupleSpaceService.setPartnerJoined(name: name)
            }
            refreshWidget()
        }
    }

    /// Partner tapped an invite link — the OS hands us the share metadata. We do
    /// NOT accept yet; we surface a confirmation sheet and only join on "Join".
    func handleAcceptedShare(_ metadata: CKShare.Metadata) async {
        pendingInvite = PendingInvite(metadata: metadata)
    }

    /// User confirmed the invite — accept the share, become a participant, sync.
    func confirmPendingJoin() async {
        guard let invite = pendingInvite else { return }
        do {
            try await cloud.acceptShare(invite.metadata)
            coupleSpaceService.connectAsParticipant(title: invite.spaceTitle,
                                                    partnerName: invite.inviterName)
            pendingInvite = nil
            syncNow()
        } catch {
            print("[CloudKit] accept share failed: \(error.localizedDescription)")
        }
    }

    /// User dismissed the invite without joining.
    func cancelPendingJoin() { pendingInvite = nil }

    // MARK: - Notification permission

    func requestNotificationPermission() {
        Task { await notifications.requestAuthorization() }
    }
}
