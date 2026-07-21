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

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - App-level UI state
    @Published var showSplash: Bool = true

    /// Set when the partner opens an invite link — drives the "confirm join" sheet.
    /// The share is only accepted once the user taps Join (see `confirmPendingJoin`).
    @Published var pendingInvite: PendingInvite?

    /// Drives the full-screen "Tying your thread…" waiting screen (design 19g/h)
    /// shown to the owner after they create a space, until their partner joins.
    @Published var showJoiningWaiter = false

    /// Sentinel partner id used before anyone has joined — matches no real record.
    static let noPartnerId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private var cancellables = Set<AnyCancellable>()

    /// Deep-link targets (widget "Send love" → Moods tab, focus the message field).
    @Published var requestedTab: Int?
    @Published var focusMoodMessage = false

    /// The partner's fresh mood, shown as the inline swipeable card on Home
    /// (designs 21a/b). Non-nil ⇒ the card is up; nil ⇒ Home shows the quiet strip.
    @Published var freshMood: MoodStatus?

    /// Reveal the fresh-mood card only when two people are connected AND the
    /// partner *changed* their mood since we last saw it. Never on first launch or
    /// for a baseline mood — see `MoodService.freshPartnerMood`. Called when Home
    /// appears / the app returns to foreground. Silent — sends nothing.
    func revealFreshMoodIfAny() {
        guard freshMood == nil, partner != nil else { return }
        guard let fresh = moodService.freshPartnerMood else { return }
        freshMood = fresh
    }

    /// Dismiss the fresh-mood card. Acknowledges the mood (so it won't re-raise)
    /// and collapses to the strip; a right swipe additionally opens the Moods tab.
    func dismissFreshMood(openMoods: Bool) {
        moodService.acknowledgePartnerMood()
        freshMood = nil
        if openMoods { requestedTab = 3 }
    }

    /// A pairing code delivered by an invite link (universal https link or the
    /// tweli:// scheme). Stashed here so it survives sign-in / "About you" and
    /// pre-fills the Join a space screen once the user reaches it.
    @Published var pendingJoinCode: String?

    /// Set while a pairing code is being redeemed / after it fails, so Join UIs
    /// can show progress and a friendly error.
    @Published var redeemingCode = false
    @Published var joinError: String?

    /// Handle a tweli:// deep link (widget "Send love", or an invite —
    /// tweli://join?code=7GK4PB → land on Join a space with the code filled).
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "tweli" else { return }
        switch url.host {
        case "sendlove", "mood":
            requestedTab = 3            // Moods tab
            focusMoodMessage = true
        case "join":
            applyInvite(from: url)
        default:
            break
        }
    }

    /// Handle an incoming Universal Link (https://<host>/join?code=…) — the
    /// tappable invite. iOS delivers it as a browsing NSUserActivity.
    func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return }
        if url.path.hasPrefix("/join") { applyInvite(from: url) }
    }

    /// Extract a `code` from any invite URL and stash it so it pre-fills the Join
    /// a space screen once the user is past sign-in / "About you".
    private func applyInvite(from url: URL) {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else { return }
        let code = FirebaseService.normalizePairCode(raw)
        guard code.count == 6 else { return }
        pendingJoinCode = code
    }

    /// Redeem a pairing code → invite metadata → the confirm-join sheet. Used by the
    /// deep link AND by manual entry in JoinSpaceView. All three input shapes (typed
    /// code, tweli://, https://…?code=) converge here.
    func joinWithCode(_ code: String) async {
        redeemingCode = true
        joinError = nil
        defer { redeemingCode = false }
        do {
            let invite = try await cloud.redeemPairCode(code)
            pendingInvite = PendingInvite(invite: invite)
        } catch {
            joinError = error.localizedDescription
        }
    }

    // MARK: - Services (shared graph)
    let auth = AuthService()
    let cloud = FirebaseService()
    let notifications = ReminderNotificationService()
    let widget = WidgetDataService()

    let coupleSpaceService: CoupleSpaceService
    let reminderService: ReminderService
    let countdownService: CountdownService
    let virtualDateService: VirtualDateService
    let letterService: OpenWhenLetterService
    let moodService: MoodService
    let missingYouService: MissingYouService
    let locationService: LocationService

    init() {
        coupleSpaceService = CoupleSpaceService(cloud: cloud)
        reminderService = ReminderService(notifications: notifications, cloud: cloud)
        countdownService = CountdownService(cloud: cloud, notifications: notifications)
        virtualDateService = VirtualDateService(cloud: cloud, notifications: notifications)
        letterService = OpenWhenLetterService(cloud: cloud)
        moodService = MoodService(cloud: cloud)
        missingYouService = MissingYouService(cloud: cloud)
        locationService = LocationService(cloud: cloud)

        wireIdentities()
        wireWidgetRefresh()
        refreshWidget()

        // Bridge AuthService's Sign in with Apple to the Firebase credential exchange
        // and sign-out, without AuthService importing Firebase.
        auth.exchangeCredential = { [cloud] idToken, rawNonce, fullName in
            let user = try await cloud.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
            return (user.uid, user.displayName)
        }
        auth.onSignOut = { [cloud] in try? cloud.signOut() }

        // When the user signs in, apply their real name + re-wire ids. A DEBUG dev
        // sign-in additionally puts FirebaseService into its offline `dev-` state.
        auth.$isSignedIn
            .sink { [weak self] signedIn in
                guard let self, signedIn else { return }
                self.coupleSpaceService.seedDisplayName(self.auth.displayName)
#if DEBUG
                if self.auth.appleUserId?.hasPrefix("dev-") == true, self.cloud.currentUid == nil {
                    self.cloud.devSignIn()
                }
#endif
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
        if auth.isSignedIn { coupleSpaceService.seedDisplayName(auth.displayName) }
        let meId = coupleSpaceService.currentUser.id
        // No partner yet → a sentinel id that matches no real record (empty data).
        let partnerId = coupleSpaceService.partner?.id ?? Self.noPartnerId
        reminderService.currentUserId = meId
        moodService.currentUserId = meId
        moodService.partnerId = partnerId
        locationService.currentUserId = meId
        locationService.partnerId = partnerId
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
        locationService.onDataChanged = refresh
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

    // MARK: - Firebase sync

    /// True once the Firestore snapshot listeners are attached, so `syncNow()` starts
    /// them exactly once (further calls just refresh the widget).
    private var listenersStarted = false

    /// Attach the live Firestore listeners once and register for push. Offline-first:
    /// Firestore's persistent cache keeps the local store authoritative when the
    /// backend is unreachable — and, unlike CloudKit, never fails on personal quota.
    func syncNow() {
        Task {
            await cloud.refreshAccountStatus()
            // Upgrade path: a pre-Firebase build left a local "signed in" flag but
            // no Firebase Auth session (the credential exchange only runs during
            // sign-in). Without a UID every Firestore call fails as .network, so
            // drop the stale session and let SignInView run the real exchange.
            if auth.isSignedIn, cloud.currentUid == nil {
                print("[Auth] stale pre-Firebase session detected — signing out to re-auth")
                auth.signOut()
                return
            }
            guard cloud.role != .none else { return }
            if !listenersStarted {
                listenersStarted = true
                cloud.startListening { [weak self] changes in
                    Task { @MainActor in self?.applyRemoteChanges(changes) }
                }
                await cloud.registerForPush()
            }
            refreshWidget()
        }
    }

    /// Merge a batch of remote changes delivered by a snapshot listener into the
    /// local services. The `RemoteChanges` shape is unchanged from the CloudKit
    /// version, so the decode + mergeRemote wiring is reused verbatim.
    private func applyRemoteChanges(_ changes: FirebaseService.RemoteChanges) {
        // Space-doc listener: partner has joined → reflect their name (replaces the
        // owner-side acceptedParticipantName() poll).
        if let name = changes.partnerJoinedName, coupleSpaceService.awaitingPartner {
            coupleSpaceService.setPartnerJoined(name: name)
        }
        let dec = JSONDecoder()
        func decode<T: Decodable>(_ type: String) -> [T] {
            (changes.payloadsByType[type] ?? []).compactMap { try? dec.decode(T.self, from: $0) }
        }
        reminderService.mergeRemote(decode(FirebaseService.RType.reminder), deletedIDs: changes.deletedIDs)
        countdownService.mergeRemote(decode(FirebaseService.RType.countdown), deletedIDs: changes.deletedIDs)
        letterService.mergeRemote(decode(FirebaseService.RType.letter), deletedIDs: changes.deletedIDs)
        virtualDateService.mergeRemote(decode(FirebaseService.RType.virtualDate), deletedIDs: changes.deletedIDs)
        moodService.mergeRemote(decode(FirebaseService.RType.mood), deletedIDs: changes.deletedIDs)
        locationService.mergeRemote(decode(FirebaseService.RType.location), deletedIDs: changes.deletedIDs)
        missingYouService.mergeRemote(decode(FirebaseService.RType.ping), deletedIDs: changes.deletedIDs)
        refreshWidget()
    }

    /// User confirmed the invite — atomically join the space, become a participant,
    /// start listeners. Returns false on failure so the confirm sheet can recover
    /// instead of sitting on a disabled "Joining…" button forever. On a space-full
    /// failure the error is surfaced via `joinError` for the confirm sheet's copy.
    func confirmPendingJoin() async -> Bool {
        guard let invite = pendingInvite else { return false }
        let participantName = coupleSpaceService.currentUser.displayName
        let pairInvite = FirebaseService.PairInvite(spaceId: invite.spaceId,
                                                    spaceTitle: invite.spaceTitle,
                                                    inviterName: invite.inviterName)
        do {
            try await cloud.joinSpace(pairInvite, participantName: participantName)
            coupleSpaceService.connectAsParticipant(title: invite.spaceTitle,
                                                    partnerName: invite.inviterName)
            pendingInvite = nil
            joinError = nil
            syncNow()
            return true
        } catch {
            print("[Firebase] join space failed: \(error.localizedDescription)")
            joinError = error.localizedDescription
            return false
        }
    }

    /// User dismissed the invite without joining.
    func cancelPendingJoin() { pendingInvite = nil }

    // MARK: - Owner "waiting for partner" flow (design 19g/h)

    /// Called from the invite-code step's Continue. Completes local setup (so the
    /// space is live and listeners start), then raises the full-screen waiting
    /// screen. When the partner joins, the space-doc listener fills in
    /// `coupleSpaceService.partner`, which the waiting screen watches to advance.
    func beginOwnerWaiting(title: String) {
        if !coupleSpaceService.isConnected {
            coupleSpaceService.createSpace(title: title)
        }
        syncNow()
        showJoiningWaiter = true
    }

    /// Dismiss the waiting screen and land in the app (partner joined, or the
    /// owner chose to enter now).
    func finishOwnerWaiting() { showJoiningWaiter = false }

    /// Finish the first-run "About you" step → advance to Create / Join.
    func finishAboutYou() {
        coupleSpaceService.completeAboutYou()
        wireIdentities()   // pick up the freshly-saved display name
    }

    // MARK: - Notification permission

    func requestNotificationPermission() {
        Task { await notifications.requestAuthorization() }
    }
}
