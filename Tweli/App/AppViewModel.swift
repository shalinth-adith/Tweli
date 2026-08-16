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

    // MARK: - Reinstall (comps K1–K5)

    private let reinstallGate = ReinstallGate()

    /// What kind of launch this is, read ONCE for the same reason `showTutorial`
    /// is: `markInstalled()` below immediately makes the answer `.sameInstall`,
    /// so anything that re-read it would lose the whole flow mid-session.
    let launch: ReinstallGate.Launch

    /// True for the entire session when the app was deleted and put back. Drives
    /// K1's copy, suppresses the 0Z tutorial (a returning user does not need to
    /// be told what Tweli is), and arms the K2 → K3/K5 sequence after sign-in.
    var isReinstall: Bool {
        if case .reinstall = launch { return true }
        return false
    }

    /// Whether this device was ever actually in a pair. Without it, "signed in,
    /// no space" is ambiguous between a returning partner whose space is gone
    /// (K5) and somebody who reinstalled before ever pairing (Start-or-join).
    var hadPairBefore: Bool {
        if case .reinstall(let hadPair) = launch { return hadPair }
        return false
    }

    @Published private(set) var restorePhase: RestorePhase = .none
    /// K2's checklist, rebuilt as each stage resolves.
    @Published private(set) var restoreSteps: [RestoreStep] = []
    /// K3's figures. Nil until the restore has actually counted them.
    @Published private(set) var restoreSummary: RestoreSummary?
    /// K5's facts.
    @Published private(set) var pairGone: PairGoneDetail?
    /// K4's two rows, filtered to whatever is genuinely undone.
    @Published private(set) var cleanup = ReinstallCleanup()

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
    func dismissFreshMood() {
        moodService.acknowledgePartnerMood()
        // Nothing else to decide. This used to take a `keep` flag that chose
        // between the prominent card and a one-line strip on Home; the strip is
        // gone and the card always rests in full, so every way out of the
        // interstitial means exactly one thing — "I've seen it".
        moodService.clearLegacyCollapseState()
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
        // A local gate, not `self.reinstallGate`: `launch` is a `let` with no
        // default, so nothing on `self` may be read until it is assigned. The
        // type is stateless, so a second instance is free.
        //
        // Read before writing. `markInstalled()` is what makes the FOLLOWING
        // launch ordinary, so the classification has to be taken first and then
        // held for the whole session.
        let gate = ReinstallGate()
        launch = gate.launch
        gate.markInstalled()

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
            return (user.uid, user.displayName, user.isNewAccount)
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
                //
                // When there is a thread to go and find, that is not a silent
                // background repair — it is comp K2, and the user should watch
                // it happen. Otherwise fall back to the quiet path.
                if self.shouldShowRestore {
                    self.beginRestore()
                } else {
                    Task { await self.recoverSpaceIfNeeded() }
                }
            }
            .store(in: &cancellables)

        // Nested ObservableObjects don't propagate through @EnvironmentObject,
        // so republish the one piece of cloud state the root routes on.
        cloud.$fatalSyncError
            .receive(on: DispatchQueue.main)
            .assign(to: &$fatalSyncError)

        if isReinstall {
            // The 0Z tutorial lives in UserDefaults, which the delete wiped — so
            // without this a returning user is taught what Tweli is on their way
            // back into a thread they have been keeping for months.
            showTutorial = false
            // K1 rather than G1, until they sign in. The Apple sheet and both
            // failure states (G3/G4) are unchanged; only the promise differs.
            if !auth.isSignedIn { restorePhase = .signIn }
        }
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
        // The moment there are genuinely two people, record it where a delete
        // can't reach. Idempotent, and this runs on every identity change, so
        // there is no single "you are now paired" event to miss.
        if coupleSpaceService.partner != nil { reinstallGate.markPaired() }
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
        // Comps RA3/RA6/RA7/RA8/RA9 — a tapped action reaches the services here.
        notifications.onAction = { [weak self] intent in
            self?.handleNotificationAction(intent)
        }
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
    // MARK: - Notification actions (comps RA3, RA6, RA7, RA8, RA9)

    /// Wired from `bootstrapNotifications`. Every case does real work — a
    /// "Mark done" that only dismissed the banner would be worse than no button,
    /// because the reminder would still be waiting when the user next looked.
    func handleNotificationAction(_ intent: NotificationActionIntent) {
        switch intent {
        case .markReminderDone(let id):
            guard let r = reminderService.reminders.first(where: { $0.id == id }) else { return }
            reminderService.toggleDone(r)
            notifications.cancelOverdueNudge(id: id)

        case .snoozeReminder(let id):
            guard let r = reminderService.reminders.first(where: { $0.id == id }) else { return }
            // RA3's button is the 15-minute one; RA4's fuller sheet is reached
            // by opening the reminder itself.
            reminderService.snooze(r, minutes: 15)
            notifications.cancelOverdueNudge(id: id)

        case .replyToPartner(let text):
            // RA3 "Reply to Anaya". Sent as a mood note, which is the only
            // free-text channel that reaches them without opening the app.
            let current = moodService.myMood?.mood ?? .thinkingOfYou
            moodService.setMyMood(current, note: text)

        case .openLetters:
            requestedTab = 3

        case .saveLetterForTonight:
            // RA7. Nothing is opened and nothing is marked read — the letter
            // simply stays sealed, which is already true. Recorded so the
            // action is honest about doing nothing destructive.
            break

        case .sendLoveBack:
            // RA8's "❤️" — the same ping the widget's Send love sends.
            missingYouService.send(.thinkingOfYou,
                                   senderName: coupleSpaceService.currentUser.displayName)

        case .checkInOnPartner:
            requestedTab = 2
            focusMoodMessage = true

        case .acceptDate, .suggestAnotherTime:
            requestedTab = 1

        case .openApp:
            break
        }
    }

    func pushMyNameToSpace() {
        Task { await cloud.updateMyMemberName(coupleSpaceService.currentUser.displayName) }
    }

    /// Push the whole profile — name AND the bio/city/birthday the X1–X6 flow
    /// collects. Without this the last three are written to UserDefaults and
    /// never leave the device, which makes X6's "this is what they see" false.
    /// - Parameter userEdited: true when this comes from a screen the user just
    ///   filled in, which is the only context where an empty field means "remove
    ///   it" rather than "this device doesn't happen to know". Incidental pushes
    ///   leave stored values alone — see `updateMyProfileDetails(allowClearing:)`.
    func pushMyProfileToSpace(userEdited: Bool = true) {
        let me = coupleSpaceService.currentUser
        Task {
            await cloud.updateMyMemberName(me.displayName)
            await cloud.updateMyTimezone()
            await cloud.updateMyProfileDetails(bio: me.bio, city: me.city,
                                               birthday: me.birthday,
                                               allowClearing: userEdited)
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
        // Identity, not just membership. Without this a reinstall lands the user
        // back in their space but with an empty profile, then walks them through
        // X1–X6 again — and finishing that pushes the blanks over their real bio
        // and birthday, wiping them from the partner's side too.
        coupleSpaceService.restoreMyProfile(name: recovered.myName,
                                            bio: recovered.myBio,
                                            city: recovered.myCity,
                                            birthday: recovered.myBirthday)
        wireIdentities()   // the partner may have just come back into existence
        syncNow()          // attach listeners to the space we just re-bound to
        reinstallGate.markPaired()
    }

    // MARK: - Reinstall restore (comps K2 → K3 / K5 → K4)

    private var restoreTask: Task<Void, Never>?

    /// Whether this sign-in should show comp K2 rather than repair silently.
    ///
    /// K2 was originally gated on the Keychain marker alone, which made it
    /// almost unreachable in practice: the marker is only written by builds that
    /// have this feature, so the FIRST install of such a build lays it down and
    /// only a LATER delete-and-reinstall can read it back. Anyone upgrading from
    /// an older build, restoring onto a new phone, or simply signing out and
    /// back in got the silent path and never saw the screen.
    ///
    /// The honest condition is not "was this a reinstall" but "is there a thread
    /// to go and find":
    ///
    ///   1. This device has no space locally — nothing to restore otherwise, and
    ///      showing progress over an already-loaded space is theatre.
    ///   2. Either our marker says reinstall, OR Firebase says the account
    ///      already existed. The second covers every device the marker cannot.
    ///
    /// A genuinely new account fails (2) and takes the silent path, so nobody is
    /// ever told we are finding a thread they have never had. `nil` (a restored
    /// session rather than a fresh sign-in) also fails it, deliberately: that is
    /// the ordinary launch, and it is handled by `recoverSpaceIfNeeded()`.
    private var shouldShowRestore: Bool {
        guard !coupleSpaceService.isConnected else { return false }
        return isReinstall || auth.signedInToExistingAccount == true
    }

    /// Raise K2 and start the work it is describing. Idempotent: a second
    /// sign-in event (Combine replays the current value to a new subscriber)
    /// must not restart a restore that is already running or finished.
    func beginRestore() {
        guard restorePhase == .none || restorePhase == .signIn else { return }
        guard restoreTask == nil else { return }
        restorePhase = .restoring
        restoreSteps = Self.initialRestoreSteps
        restoreTask = Task {
            // The splash outranks every routing branch, so a restore that
            // starts while it is up runs to completion behind it and the user
            // lands on the OUTCOME screen having never seen K2. Observed
            // exactly that: splash → "There's no pair to return to", with the
            // whole restore invisible in between.
            await waitForSplashToLift()
            // Start the clock only once the screen is actually visible —
            // otherwise the floor below is spent behind the splash and buys
            // nothing.
            restoreStartedAt = Date()
            await runRestore()
        }
    }

    private var restoreStartedAt: Date?

    /// Hold until the splash has handed over, so K2 opens on a visible screen.
    ///
    /// Polled rather than observed: `showSplash` is plain `@Published` state
    /// that SplashView flips from its own animation callback, and a one-shot
    /// await would need a subscription torn down on every exit path. The ceiling
    /// matches the root's own splash safety net — if the splash somehow never
    /// lifts, the restore must not be stranded behind it either.
    private func waitForSplashToLift(ceiling: Double = 9.0) async {
        let start = Date()
        while showSplash, Date().timeIntervalSince(start) < ceiling {
            await pause(0.1)
        }
    }

    /// The shortest time K2 may stay on screen, in seconds.
    ///
    /// Not padding. Several outcomes resolve almost instantly — a warm Firestore
    /// cache, a query that finds nothing, an account that turns out to be
    /// already connected — and a screen that appears and vanishes inside half a
    /// second reads as a glitch, not as progress. It is also the one screen that
    /// tells a returning user their thread survived; flashing that past them
    /// wastes the reassurance it exists to give.
    private static let restoreFloor: TimeInterval = 2.2

    /// Hold until K2 has been readable, then let the caller move on.
    private func holdRestoreFloor() async {
        guard let started = restoreStartedAt else { return }
        let remaining = Self.restoreFloor - Date().timeIntervalSince(started)
        guard remaining > 0 else { return }
        await pause(remaining)
    }

    /// K2's four rows, in the order the comp lists them. Held as a template so
    /// the checklist has its full shape from the first frame — rows appearing
    /// one at a time would make the screen jump as each resolves.
    private static var initialRestoreSteps: [RestoreStep] {
        [
            RestoreStep(id: "account", title: "Account verified", state: .running),
            RestoreStep(id: "pair", title: "Finding your pair"),
            RestoreStep(id: "items", title: "Reminders & letters"),
            // "Their", not the comp's "Her". This row names the real user's real
            // partner, whoever they are — K3 and the Home card already say
            // "their", and the live run showed K2 as the one screen still
            // guessing. The comp's copy is written about its own example couple.
            RestoreStep(id: "mood", title: "Their mood & planned dates"),
        ]
    }

    private func setStep(_ id: String, _ state: RestoreStep.State, detail: String? = nil) {
        guard let i = restoreSteps.firstIndex(where: { $0.id == id }) else { return }
        restoreSteps[i].state = state
        if let detail { restoreSteps[i].detail = detail }
    }

    private func setStepTitle(_ id: String, _ title: String) {
        guard let i = restoreSteps.firstIndex(where: { $0.id == id }) else { return }
        restoreSteps[i].title = title
    }

    /// The whole of K2, and the decision about which screen follows it.
    ///
    /// Paced, not padded: each stage waits on real work and then holds briefly
    /// so the row it just ticked is legible. A restore that genuinely takes four
    /// seconds shows four seconds of progress; one that takes 300ms still reads
    /// as a sequence rather than a flash.
    private func runRestore() async {
        await cloud.refreshAccountStatus()
        setStep("account", .done)
        await pause(0.45)

        setStep("pair", .running)
        let outcome = await cloud.restoreSpace()

        switch outcome {
        case .partnerLeft(let space):
            await finishAsPairGone(name: space.leftByName, leftAt: space.leftAt)

        case .nothingToRestore, .unreachable:
            // Already connected locally (a re-sign-in on a device that never
            // lost its space) is the ordinary case and is not a failure.
            if coupleSpaceService.isConnected {
                await finishAsRejoined(space: nil)
            } else if hadPairBefore, case .nothingToRestore = outcome {
                // The account is fine and the server answered — there is simply
                // no space left. Only `.nothingToRestore` may conclude this;
                // `.unreachable` says nothing about whether a pair exists.
                await finishAsPairGone(name: nil, leftAt: nil)
            } else {
                // Never paired, or we could not reach the server. Fall through
                // to the ordinary routing (Start-or-join), which retries on the
                // next launch. Still held to the floor: a screen that appears
                // and disappears between two frames is worse than one that took
                // a moment and then moved on.
                setStep("pair", .skipped)
                setStepTitle("pair", "No pair found")
                await holdRestoreFloor()
                endRestore()
            }

        case .restored(let space):
            coupleSpaceService.restoreFromRecoveredSpace(title: space.title,
                                                         isOwner: space.isOwner,
                                                         partnerName: space.partnerName)
            coupleSpaceService.restoreMyProfile(name: space.myName,
                                                bio: space.myBio,
                                                city: space.myCity,
                                                birthday: space.myBirthday)
            wireIdentities()
            reinstallGate.markPaired()

            let days = space.pairedDays
            setStep("pair", .done,
                    detail: days.map { "\($0) \($0 == 1 ? "day" : "days")" })
            setStepTitle("pair", space.partnerName.map { "Pair found — \($0)" }
                                 ?? "Pair found")
            await pause(0.5)

            // Attach the listeners and let them deliver. Everything K3 counts is
            // read back out of the local services afterwards, so the figures it
            // prints are the same records the next screen shows.
            setStep("items", .running)
            syncNow()
            await waitForSyncToSettle()

            let letters = letterService.letters.count
            let reminders = reminderService.reminders.count
            setStep("items", reminders + letters > 0 ? .done : .skipped,
                    detail: reminders + letters > 0 ? "\(reminders + letters) items" : nil)
            await pause(0.35)

            setStep("mood", moodService.partnerMood != nil || !virtualDateService.dates.isEmpty
                            ? .done : .skipped)
            await pause(0.4)

            await finishAsRejoined(space: space)
        }
    }

    /// Give the listeners a chance to deliver, then stop as soon as the local
    /// store stops growing.
    ///
    /// There is no "first snapshot" callback to await: `startListening` only
    /// invokes its handler when a batch is non-empty, so an empty space would
    /// never call back and a plain await would hang for the full timeout. Settle
    /// detection handles both — a space with data finishes shortly after the
    /// last batch lands, an empty one finishes at the floor.
    private func waitForSyncToSettle(floor: Double = 1.2,
                                     ceiling: Double = 6.0) async {
        let start = Date()
        var lastCount = -1
        var stableTicks = 0

        while Date().timeIntervalSince(start) < ceiling {
            await pause(0.25)
            let count = reminderService.reminders.count
                + letterService.letters.count
                + virtualDateService.dates.count
                + moodService.moods.count
            stableTicks = (count == lastCount) ? stableTicks + 1 : 0
            lastCount = count
            // Two quiet ticks AND past the floor. The floor is not decoration:
            // Firestore's cache answers a warm query in milliseconds, and a
            // checklist that ticks four rows in one frame reads as a glitch.
            if stableTicks >= 2, Date().timeIntervalSince(start) >= floor { return }
        }
    }

    private func finishAsRejoined(space: FirebaseService.RecoveredSpace?) async {
        await holdRestoreFloor()
        restoreSummary = RestoreCounting.summary(
            partnerName: coupleSpaceService.partner?.displayName ?? "your partner",
            pairedDays: space?.pairedDays,
            reminders: reminderService.reminders,
            letters: letterService.letters,
            partnerMood: moodService.partnerMood,
            dates: virtualDateService.dates)
        await refreshCleanupState()
        restorePhase = .rejoined
        restoreTask = nil
    }

    private func finishAsPairGone(name: String?, leftAt: Date?) async {
        // The listeners still need to run: K5's "kept for you" counts real
        // letters and finished reminders, and they only exist locally once the
        // space we are still a member of has synced.
        syncNow()
        await waitForSyncToSettle(floor: 0.8, ceiling: 4.0)
        await holdRestoreFloor()
        pairGone = RestoreCounting.keepsakes(partnerName: name,
                                             leftAt: leftAt,
                                             reminders: reminderService.reminders,
                                             letters: letterService.letters)
        restorePhase = .pairGone
        restoreTask = nil
    }

    /// K3's "Open Tweli" — go to K4 if anything is genuinely undone, otherwise
    /// straight into the app.
    func finishRejoined() {
        Task {
            await refreshCleanupState()
            withAnimation(.easeInOut(duration: 0.35)) {
                restorePhase = cleanup.isEmpty ? .none : .cleanup
            }
        }
    }

    /// K4's "Later", and the exit from every other K screen.
    func endRestore() {
        withAnimation(.easeInOut(duration: 0.35)) { restorePhase = .none }
        restoreTask = nil
    }

    /// K5 → "Start a new thread": drop the dead space and land on Start-or-join.
    func startFreshAfterPairGone() {
        coupleSpaceService.disconnect()
        cloud.reset()
        listeningSpaceId = nil
        pairGone = nil
        endRestore()
    }

    /// Ask the system what is actually missing. Both answers come from iOS, not
    /// from an assumption about what a reinstall usually wipes — telling someone
    /// their widget is gone when it is sitting on their Home Screen is the same
    /// class of untruth as inventing a count.
    func refreshCleanupState() async {
        let widgets = await widget.installedWidgetCount()
        let status = await notifications.currentAuthorizationStatus()
        cleanup = ReinstallCleanup(
            // `nil` is "WidgetKit didn't answer", which is not the same as
            // "there are none" — so it claims nothing.
            widgetMissing: widgets == 0,
            notificationsOff: status != .authorized)
    }

    /// K4's "Turn on notifications". Re-checks afterwards so the row disappears
    /// on success and stays put (pointing at Settings) on a denial.
    func requestNotificationsFromCleanup() async {
        _ = await notifications.requestAuthorization()
        await refreshCleanupState()
        if cleanup.isEmpty { endRestore() }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

#if DEBUG
    /// Verification hook (DEBUG only, compiled out of every distribution build).
    ///
    /// Reaching K2–K5 for real needs a signed-in Apple account, a live space and
    /// an actual uninstall — none of which a headless simulator can do, and it
    /// cannot inject the taps to walk there either. This is the only door into
    /// those states for a screenshot.
    ///
    /// It takes prepared values rather than inventing any: the stand-in figures
    /// live in `RestoreCapturePreviews.swift`, which is where a reader looks for
    /// fake data and where the pre-ship grep expects to find it. Nothing here is
    /// written to storage or pushed anywhere.
    func applyRestoreCaptureState(phase: RestorePhase,
                                  steps: [RestoreStep] = [],
                                  summary: RestoreSummary? = nil,
                                  gone: PairGoneDetail? = nil,
                                  pendingCleanup: ReinstallCleanup = ReinstallCleanup()) {
        restoreSteps = steps
        restoreSummary = summary
        pairGone = gone
        cleanup = pendingCleanup
        restorePhase = phase
    }
#endif

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
        restorePhase = .none
        restoreSummary = nil
        pairGone = nil
        // The Keychain marker describes an account that no longer exists.
        // Leaving it would greet the next install with "welcome back" — and,
        // worse, `hadPair` would send a genuinely new user to comp K5.
        reinstallGate.forget()

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
