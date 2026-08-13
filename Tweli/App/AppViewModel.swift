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

    /// Comp 0Z — the three-page entry tutorial. True only on a fresh install.
    ///
    /// The gate is read HERE and nowhere else: a property initializer runs once,
    /// when AppViewModel is constructed, which is once per launch. Reading it on
    /// access instead (a computed property, or a re-read in `body`) would let the
    /// tutorial reappear mid-session the moment anything else wrote to
    /// UserDefaults and invalidated a view.
    ///
    /// `private(set)` so the only way it can ever go false is `finishTutorial()`,
    /// and nothing outside this type can set it back to true. That makes
    /// "it shows once" a compile-time guarantee rather than a convention.
    @Published private(set) var showTutorial: Bool = !TutorialGate().hasSeen

    private let tutorialGate = TutorialGate()

    /// Skip or finish — both mean "never show this again".
    func finishTutorial() {
        tutorialGate.markSeen()
        withAnimation(.easeInOut(duration: 0.35)) { showTutorial = false }
    }

    /// Set when the partner opens an invite link — drives the "confirm join" sheet.
    /// The share is only accepted once the user taps Join (see `confirmPendingJoin`).
    @Published var pendingInvite: PendingInvite?

    /// The partner's IANA timezone as reported by THEIR device via the space
    /// doc. Independent of location sharing.
    @Published var partnerDeviceTimeZoneId: String?

    /// The partner's zone, best source first.
    ///
    /// Their device's own `TimeZone.current` beats anything derived from a
    /// location fix: it is exact, it updates on every sync, and it needs no
    /// permission. The geocoded zone from their shared location is only a
    /// fallback for the window before the first space-doc snapshot lands.
    var partnerTimeZoneId: String? {
        partnerDeviceTimeZoneId ?? locationService.partnerLocation?.timeZoneId
    }

    /// Convenience for views that want a resolved zone or nothing.
    var partnerTimeZone: TimeZone? {
        partnerTimeZoneId.flatMap(TimeZone.init(identifier:))
    }

    /// Mirrors `cloud.fatalSyncError` so RootView — which observes this object,
    /// not the nested service — can raise comp E8.
    @Published var fatalSyncError: String?

    /// Set when the partner removed themselves from the space — drives the
    /// full-screen E6 "…left the space" scene. Carries their name so the copy
    /// can say who, not "your partner".
    @Published var partnerLeftName: String?

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

    /// Resolve the fresh-mood interstitial (designs 22a/b). Always acknowledges the
    /// mood so it won't re-raise. `keep` (right swipe) leaves the prominent mood
    /// card on Home; otherwise (left swipe / × / scrim) it collapses to the strip.
    func dismissFreshMood(keep: Bool) {
        moodService.acknowledgePartnerMood()
        moodService.setPartnerMoodKept(keep)
        freshMood = nil
    }

    /// A pairing code delivered by an invite link (universal https link or the
    /// tweli:// scheme). Stashed here so it survives sign-in / "About you" and
    /// pre-fills the Join a space screen once the user reaches it.
    @Published var pendingJoinCode: String?

    /// Set while a pairing code is being redeemed / after it fails, so Join UIs
    /// can show progress and a friendly error.
    @Published var redeemingCode = false
    @Published var joinError: String?
    /// The typed failure behind `joinError`. Comps J4 and J5 are different
    /// screens — "that code does not match any space" offers a retry, while an
    /// expired code offers to ask for a fresh one — and the localized string
    /// alone cannot tell them apart.
    @Published var joinErrorKind: FirebaseService.PairCodeError?

    /// Handle a tweli:// deep link (widget "Send love", or an invite —
    /// tweli://join?code=7GK4PB → land on Join a space with the code filled).
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "tweli" else { return }
        switch url.host {
        case "sendlove", "mood":
            requestedTab = 2            // Moods tab
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
        guard FirebaseService.isPlausiblePairCode(code) else { return }
        pendingJoinCode = code
    }

    /// Redeem a pairing code → invite metadata → the confirm-join sheet. Used by the
    /// deep link AND by manual entry in JoinSpaceView. All three input shapes (typed
    /// code, tweli://, https://…?code=) converge here.
    func joinWithCode(_ code: String) async {
        redeemingCode = true
        joinError = nil
        joinErrorKind = nil
        defer { redeemingCode = false }
        do {
            let invite = try await cloud.redeemPairCode(code)
            pendingInvite = PendingInvite(invite: invite)
        } catch {
            joinError = error.localizedDescription
            joinErrorKind = error as? FirebaseService.PairCodeError
        }
    }

    // MARK: - Services (shared graph)
    let auth = AuthService()
    let cloud = FirebaseService()
    let notifications = ReminderNotificationService()
    let widget = WidgetDataService()
    /// Light / Dark / Auto — applied as a preferredColorScheme at the root, which
    /// is what makes the L and N palettes selectable (see DesignSystem.swift).
    let theme = ThemeService()
    /// Arms an App Store rating ask at genuinely happy moments, fires it later
    /// at a calm one. See ReviewPromptService for why those are separate.
    let review = ReviewPromptService()

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
        auth.revokeAppleToken = { [cloud] code in
            try await cloud.revokeAppleToken(authorizationCode: code)
        }

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
                // A returning user may still be a member of a space this device
                // knows nothing about (reinstall, new phone, or sign-out).
                Task { await self.recoverSpaceIfNeeded() }
            }
            .store(in: &cancellables)

        // Nested ObservableObjects don't propagate through @EnvironmentObject,
        // so republish the one piece of cloud state the root routes on.
        cloud.$fatalSyncError
            .receive(on: DispatchQueue.main)
            .assign(to: &$fatalSyncError)
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
        // The partner's name appears inside already-scheduled alerts, so when it
        // arrives (they joined) or changes (they renamed), the pending alerts
        // have to be rewritten — rescheduling is idempotent, keyed by reminder id.
        let newPartnerName = coupleSpaceService.partner?.displayName ?? ""
        let partnerNameChanged = reminderService.partnerName != newPartnerName
        reminderService.partnerName = newPartnerName
        if partnerNameChanged, didBootstrap { reminderService.scheduleAll() }
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
        // Every field is real or empty — the widget renders its own "nothing
        // shared yet" state rather than being handed a stand-in string.
        let cd = countdownService.countdowns.first { $0.category == .meeting } ?? countdownService.pinned
        let mood = moodService.partnerMood
        let snapshot = WidgetSnapshot(
            daysUntil: cd?.daysRemaining ?? 0,
            countdownProgress: cd?.progress ?? 0,
            partnerName: coupleSpaceService.partner?.displayName ?? "Your partner",
            partnerMood: mood?.displayLabel ?? "",
            partnerMoodNote: mood?.note ?? "",
            userInitial: currentUser.initials
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

    /// The spaceId the live listeners are currently bound to. Comparing against
    /// `cloud.spaceId` (instead of a "started once" flag) means leave→rejoin and
    /// sign-out→re-create automatically REBIND the listeners to the new space —
    /// a boolean left them attached to the old space until the next app launch.
    private var listeningSpaceId: String?

    /// Attach the live Firestore listeners once per space and register for push.
    /// Offline-first: Firestore's persistent cache keeps the local store
    /// authoritative when the backend is unreachable — and, unlike CloudKit, never
    /// fails on personal quota.
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
            if listeningSpaceId != cloud.spaceId {
                listeningSpaceId = cloud.spaceId
                cloud.startListening { [weak self] changes in
                    Task { @MainActor in self?.applyRemoteChanges(changes) }
                }
                await cloud.registerForPush()
                // Repair the cloud copy of my name (createSpace may have written
                // the "You" placeholder before "About you" ran).
                await cloud.updateMyMemberName(coupleSpaceService.currentUser.displayName)
                // Publish my timezone so the push function can respect the
                // recipient's quiet hours (silent overnight in their local time).
                await cloud.updateMyTimezone()
            }
            refreshWidget()
        }
    }

    /// Push my current profile name into the space doc — called after "About you"
    /// saves so the partner's device reflects a rename via its space-doc listener.
    func pushMyNameToSpace() {
        Task { await cloud.updateMyMemberName(coupleSpaceService.currentUser.displayName) }
    }

    /// Push the whole profile — name AND the bio/city/birthday the X1–X6 flow
    /// collects. Without this the last three are written to UserDefaults and
    /// never leave the device, which makes X6's "this is what they see" false.
    func pushMyProfileToSpace() {
        let me = coupleSpaceService.currentUser
        Task {
            await cloud.updateMyMemberName(me.displayName)
            await cloud.updateMyTimezone()
            await cloud.updateMyProfileDetails(bio: me.bio, city: me.city, birthday: me.birthday)
        }
    }

    /// Leave the shared space: announce the departure so the partner's device
    /// can show E6, then clear local couple state AND detach cloud
    /// role/spaceId/listeners so a later join binds cleanly to the new space.
    ///
    /// The announcement is awaited before the teardown, because `cloud.reset()`
    /// drops the spaceId the write needs.
    func leaveSpace() {
        Task {
            await cloud.announceLeave()
            coupleSpaceService.disconnect()
            cloud.reset()
            listeningSpaceId = nil
            partnerLeftName = nil
        }
    }

    /// Rejoin a space we are still a member of but have no local record of.
    ///
    /// Runs on sign-in and once at launch, and is a no-op whenever a spaceId is
    /// already cached — so the normal path costs nothing. Without it, signing
    /// out and back in (or reinstalling, or using a second phone) dropped the
    /// user on Start-or-join while their space and partner sat intact in
    /// Firestore.
    func recoverSpaceIfNeeded() async {
        guard !coupleSpaceService.isConnected else { return }
        // At cold launch the Keychain session may not have been read yet, and
        // the query guards on a non-nil uid — without this the launch-time
        // attempt would silently no-op and recovery would wait for a re-sign-in.
        await cloud.refreshAccountStatus()
        guard let recovered = await cloud.restoreSpaceMembership() else { return }
        coupleSpaceService.restoreFromRecoveredSpace(title: recovered.title,
                                                     isOwner: recovered.isOwner,
                                                     partnerName: recovered.partnerName)
        wireIdentities()   // the partner may have just come back into existence
        syncNow()          // attach listeners to the space we just re-bound to
    }

    /// Sign out WITHOUT leaving the shared space.
    ///
    /// `leaveSpace()` announces a departure so the partner sees the "left the
    /// space" screen. Signing out must not: nothing has happened to them, and
    /// your membership has to survive so you can sign back in. Local couple
    /// state is still cleared so a different account can't inherit it.
    func signOut() {
        coupleSpaceService.disconnect()
        cloud.reset()
        listeningSpaceId = nil
        partnerLeftName = nil
        auth.signOut()
    }

    /// Comp E8 "Try again" — drop the failure and re-attach the listeners.
    func retryAfterFatalError() {
        cloud.clearFatalSyncError()
        listeningSpaceId = nil      // force startListening to re-bind
        syncNow()
    }

    // MARK: - Account deletion

    /// Permanently deletes the account: re-authenticate with Apple (which both
    /// proves intent and yields the fresh code Apple's token revocation needs),
    /// destroy everything server-side, then erase every local trace.
    ///
    /// Throws so the caller can show why it failed. Nothing local is cleared
    /// unless the server confirmed the deletion — a half-wiped device that is
    /// still a live account is the worst outcome here.
    /// - Parameter keepLetters: comp W3's toggle — leave the letters you wrote
    ///   with your partner instead of erasing them along with everything else.
    func deleteAccountPermanently(keepLetters: Bool = false) async throws {
        try await auth.reauthenticateAndRevokeAppleToken()
        try await cloud.deleteAccount(keepLetters: keepLetters)
        wipeLocalState()
        auth.forgetLocalIdentity()
    }

    /// Erases everything this app persisted on-device, including the App Group
    /// payload the widget reads — otherwise a deleted account's last mood keeps
    /// sitting on the Home Screen.
    private func wipeLocalState() {
        notifications.removeAllPending()
        coupleSpaceService.disconnect()
        listeningSpaceId = nil
        partnerLeftName = nil
        partnerDeviceTimeZoneId = nil
        freshMood = nil
        pendingInvite = nil
        pendingJoinCode = nil

        let defaults = UserDefaults.standard
        for key in [
            "tweli.aboutYouDone", "tweli.auth.appleUserId", "tweli.auth.displayName",
            "tweli.coupleSpace", "tweli.currentUser", "tweli.fb.pairCode",
            "tweli.fb.pairCodeExpiry", "tweli.fb.role", "tweli.fb.spaceId",
            "tweli.mood.collapsedToStrip", "tweli.mood.lastSeenPartner",
            "tweli.partner", "tweli.roomSetupComplete", "tweli.theme",
        ] {
            defaults.removeObject(forKey: key)
        }
        widget.clear()
    }

    /// E6 → "Send a new invite": stay signed in, drop the dead space, and land
    /// back on Start-or-join so a fresh code can be minted.
    func startFreshAfterPartnerLeft() {
        partnerLeftName = nil
        coupleSpaceService.disconnect()
        cloud.reset()
        listeningSpaceId = nil
    }

    /// Merge a batch of remote changes delivered by a snapshot listener into the
    /// local services. The `RemoteChanges` shape is unchanged from the CloudKit
    /// version, so the decode + mergeRemote wiring is reused verbatim.
    private func applyRemoteChanges(_ changes: FirebaseService.RemoteChanges) {
        // Space-doc listener: partner joined OR renamed → reflect their current
        // name (replaces the owner-side acceptedParticipantName() poll). Applied
        // unconditionally: gating on awaitingPartner froze the join-time "You"
        // placeholder forever on the participant's device.
        // The partner walked out (comp E6). Raise the scene and stop here —
        // there is nothing else in this batch worth merging into a space that
        // no longer has two people in it.
        if let goneName = changes.partnerLeftName {
            coupleSpaceService.updatePartnerName(goneName)
            partnerLeftName = goneName
            return
        }
        if let zone = changes.partnerTimeZoneId { partnerDeviceTimeZoneId = zone }
        if let name = changes.partnerJoinedName {
            coupleSpaceService.updatePartnerName(name)
            wireIdentities()   // partner may have just been created — rewire ids
            // This block runs on every sync, not only at the moment of pairing,
            // so the one-shot check lives inside the service.
            review.notePartnerPresent()
        }
        // The rest of their profile (comps X4–X6). Applied after the name so the
        // partner record already exists to write onto.
        coupleSpaceService.updatePartnerDetails(bio: changes.partnerBio,
                                                city: changes.partnerCity,
                                                birthday: changes.partnerBirthday)
        // Their birthday is the one profile field that has to become an alarm —
        // X3 promises a "quiet nudge before", and this is what keeps it.
        notifications.schedulePartnerBirthday(coupleSpaceService.partner?.birthday,
                                              partnerName: coupleSpaceService.partner?.displayName ?? "")
        let dec = JSONDecoder()
        let myUid = cloud.currentUid

        /// Decode, and re-stamp anything I wrote with my CURRENT local id.
        ///
        /// Moods and locations decide "mine vs theirs" by comparing the payload's
        /// `userId` to `currentUserId` — a device-local UUID that is regenerated
        /// whenever the local profile is recreated (reinstall, sign out and back
        /// in). After that happens my own older records carry a stale id, so they
        /// no longer match "mine" and start being read as my partner's. Because
        /// my device keeps writing, they are also always the NEWEST such record,
        /// so "newest wins" picks them every time.
        ///
        /// Observed live: a partner genuinely in Abu Dhabi, with the Home screen
        /// reporting "8 m apart" — the gap between two of the user's own fixes.
        ///
        /// `authorUid` is the Firebase uid and survives all of that, so it is the
        /// honest answer to "did I write this". Rewriting the local id here fixes
        /// every consumer at once, without threading the author through seven
        /// mergeRemote signatures.
        let meId = coupleSpaceService.currentUser.id
        func decode<T: Decodable>(_ type: String) -> [T] {
            (changes.payloadsByType[type] ?? []).compactMap { entry in
                RecordAuthorship.decode(T.self, from: entry.data, decoder: dec,
                                        authorUid: entry.authorUid,
                                        myUid: myUid, myLocalId: meId)
            }
        }
        reminderService.mergeRemote(decode(FirebaseService.RType.reminder), deletedIDs: changes.deletedIDs)
        countdownService.mergeRemote(decode(FirebaseService.RType.countdown), deletedIDs: changes.deletedIDs)
        letterService.mergeRemote(decode(FirebaseService.RType.letter), deletedIDs: changes.deletedIDs)
        virtualDateService.mergeRemote(decode(FirebaseService.RType.virtualDate), deletedIDs: changes.deletedIDs)
        moodService.mergeRemote(decode(FirebaseService.RType.mood), deletedIDs: changes.deletedIDs)
        // First entry into the session: the partner's pre-existing mood usually
        // lands via this listener AFTER Home is already up — greet the moment it
        // arrives (only until the first acknowledge; later moods keep the calmer
        // appear/foreground reveal triggers).
        if !moodService.hasGreetedPartnerMood { revealFreshMoodIfAny() }
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
        wireIdentities()      // pick up the freshly-saved display name
        pushMyNameToSpace()   // no-op unless already connected (e.g. re-run)
    }

    // MARK: - Notification permission

    func requestNotificationPermission() {
        Task { await notifications.requestAuthorization() }
    }
}
