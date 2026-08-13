//
//  ProfileFlowView.swift
//  Tweli
//
//  Comps X1–X6 (dark) / XL1–XL6 (light) — the "OX" profile flow. One question
//  per screen, asked right after first sign-in:
//
//    X1  First name   — required, 20 characters
//    X2  Last name    — optional, "skip it and keep going"
//    X3  Birthday     — inline wheel, must be 13 or older
//    X4  City         — live suggestions from MapKit, or use my location
//    X5  Bio          — one line, 120 characters
//    X6  Complete     — the card as the partner will see it
//
//  The designed error states are states of these same screens, so they are
//  built in rather than treated as extra work: X7 name empty, X8 name too long,
//  X9 too young, X10 city not found, X11 bio too long. X12/X13 ("save failed")
//  are not built — see the note on `finish()`.
//
//  Why one question per page instead of the old single form (AboutYouView):
//  the comp's bet is that six small asks feel lighter than one wall of fields,
//  and that a person who has just signed in will answer a question but abandon
//  a form. AboutYouView stays as the Settings editor, where a form is right
//  because the user came to change one specific thing.
//

import SwiftUI
import MapKit
import UIKit
import Combine

struct ProfileFlowView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var location: LocationService

    @State private var step = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthday: Date?
    @State private var city = ""
    @State private var timezoneId: String = TimeZone.current.identifier
    @State private var bio = ""

    /// Set when Continue is tapped on an invalid field. Cleared on the next
    /// keystroke, so the screen nags once and then gets out of the way.
    @State private var showValidation = false

    @StateObject private var cities = CitySearch()
    @FocusState private var fieldFocused: Bool

    static let nameLimit = 20
    static let bioLimit = 120
    static let minimumAge = 13

    private static let stepCount = 6

    var body: some View {
        ZStack {
            Color.twBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch step {
                        case 0: firstNameStep
                        case 1: lastNameStep
                        case 2: birthdayStep
                        case 3: cityStep
                        case 4: bioStep
                        default: completeStep
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)

                footer
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onAppear(perform: prefill)
#if DEBUG
        .onAppear {
            // Verification hook (DEBUG only, same shape as TWELI_TUTORIAL_PAGE):
            // TWELI_PROFILE_STEP=<0-5> opens straight to a step, because
            // simulators cannot inject the typing each step needs to advance.
            if let raw = ProcessInfo.processInfo.environment["TWELI_PROFILE_STEP"],
               let s = Int(raw), (0..<Self.stepCount).contains(s) {
                step = s
            }
        }
#endif
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 12) {
            if step > 0 && step < Self.stepCount - 1 {
                Button { back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.twInk)
                        .frame(width: 38, height: 38)
                        .background(Color.twInk.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 38, height: 38)
            }

            // Comp: a segmented rail rather than dots — six steps is enough that
            // a person wants to see how much is left.
            HStack(spacing: 4) {
                ForEach(0..<Self.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.twAccent : Color.twInk.opacity(0.14))
                        .frame(height: 4)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
            .accessibilityElement()
            .accessibilityLabel("Step \(step + 1) of \(Self.stepCount)")

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 10) {
            BrandCTA(title: ctaTitle, showsArrow: false) { advance() }
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.5)

            // X2 is the only optional step the comp lets you jump.
            if step == 1 {
                Button("Skip") { withAnimation { step += 1 } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInkSecondary)
                    .frame(height: 34)
            } else {
                Color.clear.frame(height: 34)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private var ctaTitle: String {
        switch step {
        case 4:  return "Finish"
        case 5:  return "Enter Tweli"
        default: return "Continue"
        }
    }

    /// Only the two genuinely blocking rules gate the button; everything else is
    /// reported inline once Continue is tapped. A disabled button with no
    /// explanation is the worst of both worlds.
    private var canAdvance: Bool {
        switch step {
        case 0:  return !trimmedFirst.isEmpty && trimmedFirst.count <= Self.nameLimit
        case 4:  return bio.count <= Self.bioLimit
        default: return true
        }
    }

    // MARK: - Steps

    /// X1 · First name
    private var firstNameStep: some View {
        stepBody(
            title: "Your first name:",
            hint: firstNameHint,
            hintIsError: showValidation && firstNameError != nil
        ) {
            BigField(text: $firstName, placeholder: "First name", focused: $fieldFocused)
                .textContentType(.givenName)
                .onChange(of: firstName) { _, _ in showValidation = false }
        }
    }

    private var firstNameError: String? {
        if trimmedFirst.isEmpty {
            // X7. Names the partner if we know them, which is the comp's copy.
            let who = couple.partner?.displayName ?? "Your partner"
            return "\(who) needs something to call you."
        }
        if trimmedFirst.count > Self.nameLimit {
            // X8 — the comp shows the count, which makes the fix obvious.
            return "Names can be up to \(Self.nameLimit) characters — \(trimmedFirst.count) used."
        }
        return nil
    }

    private var firstNameHint: String {
        if showValidation, let e = firstNameError { return e }
        return "This is what they see on your profile."
    }

    /// X2 · Last name
    private var lastNameStep: some View {
        stepBody(
            title: "Your last name:",
            hint: showValidation && lastName.count > Self.nameLimit
                ? "Names can be up to \(Self.nameLimit) characters — \(lastName.count) used."
                : "Optional — skip it and keep going.",
            hintIsError: showValidation && lastName.count > Self.nameLimit
        ) {
            BigField(text: $lastName, placeholder: "Last name", focused: $fieldFocused)
                .textContentType(.familyName)
                .onChange(of: lastName) { _, _ in showValidation = false }
        }
    }

    /// X3 · Birthday
    private var birthdayStep: some View {
        stepBody(
            title: "Your date of birth",
            hint: birthdayHint,
            hintIsError: showValidation && !isOldEnough
        ) {
            DatePicker("",
                       selection: Binding(get: { birthday ?? Self.defaultBirthday },
                                          set: { birthday = $0; showValidation = false }),
                       in: ...Date(),
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Date of birth")
        }
    }

    /// The comp's reward for filling this in: it tells you what the date buys.
    private var birthdayHint: String {
        if showValidation && !isOldEnough {
            return "You need to be at least \(Self.minimumAge) to join."   // X9
        }
        guard let birthday, let days = Self.daysUntilNextBirthday(birthday) else {
            return "They get a quiet nudge before it comes around."
        }
        let who = couple.partner?.displayName ?? "Your partner"
        if days == 0 { return "That's today — happy birthday." }
        return "\(days) day\(days == 1 ? "" : "s") away — \(who) gets a quiet nudge before."
    }

    /// X4 · City
    private var cityStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            cityQuestion
            // Below the hint, not between it and the field: the hint explains
            // what the field is for, and a button wedged in between orphans the
            // sentence from the thing it describes.
            Button {
                location.requestAndCapture()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
                    Text("Use my location instead").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.twAccent2)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.twAccent2Soft, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
    }

    private var cityQuestion: some View {
        stepBody(
            title: "Where in the world are you?",
            hint: showValidation && cityNotFound
                ? "We can't find a city called \(trimmedCity)."   // X10
                : "So they always know what time it is for you.",
            hintIsError: showValidation && cityNotFound
        ) {
            VStack(alignment: .leading, spacing: 0) {
                BigField(text: $city, placeholder: "Your city", focused: $fieldFocused)
                    .textContentType(.addressCity)
                    .onChange(of: city) { _, new in
                        showValidation = false
                        cities.query(new)
                    }

                if !cities.results.isEmpty {
                    // X10 labels the list "Did you mean" once the typed value is
                    // wrong; X4 shows the same list unlabelled while typing.
                    if showValidation && cityNotFound {
                        Text("Did you mean")
                            .font(.system(size: 12, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Color.twInkTertiary)
                            .padding(.top, 18)
                            .padding(.bottom, 8)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(cities.results.enumerated()), id: \.element.id) { i, item in
                            if i > 0 { Divider().overlay(Color.twSeparator) }
                            Button { choose(item) } label: { cityRow(item) }
                                .buttonStyle(.plain)
                        }
                    }
                    .background(Color.twElevated,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, showValidation && cityNotFound ? 0 : 16)
                }

            }
            // A location fix reverse-geocodes to a city — fill the field with it.
            .onChange(of: location.myLocation?.cityLabel) { _, label in
                guard let label, !label.isEmpty else { return }
                city = label
                cities.clear()
                if let tz = location.myLocation?.timeZoneId { timezoneId = tz }
            }
        }
    }

    private func cityRow(_ item: CitySearch.Result) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.city)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                Text(item.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.left")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.twInkQuaternary)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    /// X5 · Bio
    private var bioStep: some View {
        stepBody(
            title: "Say something about you.",
            hint: bio.count > Self.bioLimit
                ? "A little too long — trim it down."   // X11
                : "One line they see on your profile.",
            hintIsError: bio.count > Self.bioLimit
        ) {
            VStack(alignment: .trailing, spacing: 10) {
                TextField("Night owl, terrible at goodbyes…", text: $bio, axis: .vertical)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.twInk)
                    .tint(Color.twAccent)
                    .lineLimit(3...5)
                    .focused($fieldFocused)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(bio.count > Self.bioLimit ? Color.twAccent : Color.twInk.opacity(0.18))
                            .frame(height: 1.5)
                    }

                Text("\(bio.count)/\(Self.bioLimit)")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(bio.count > Self.bioLimit ? Color.twAccent : Color.twInkTertiary)
                    .monospacedDigit()
            }
        }
    }

    /// X6 · Complete — the profile card exactly as the partner will see it.
    private var completeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You’re all set!")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.7)
                .foregroundStyle(Color.twInk)
                .padding(.top, 6)

            VStack(spacing: 0) {
                Circle()
                    .fill(TweliGradient.meAvatar)
                    .frame(width: 78, height: 78)
                    .overlay {
                        Text(initials)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Brand.pink.opacity(0.35), radius: 14, y: 8)

                Text(composedName)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 14)

                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.twInkSecondary)
                        .padding(.top, 4)
                }

                if !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("“\(bio.trimmingCharacters(in: .whitespacesAndNewlines))”")
                        .font(.system(size: 14.5))
                        .italic()
                        .foregroundStyle(Color.twInkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                        .padding(.horizontal, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background {
                let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
                shape.fill(LinearGradient(colors: [.twElevated2, .twElevatedWarm],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay { shape.strokeBorder(Color.twAccent2.opacity(0.3), lineWidth: 1) }
            }
            .padding(.top, 22)

            Text(partnerSeesLine)
                .font(.system(size: 13))
                .foregroundStyle(Color.twInkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    private var partnerSeesLine: String {
        let who = couple.partner?.displayName ?? "your partner"
        return "This is what \(who) sees when they\nopen your profile."
    }

    // MARK: - Step scaffold

    /// Every step is the same shape: a question, the control, one line of help.
    /// Anything a step needs *below* the hint (X4's "use my location") is
    /// composed outside this call rather than passed in — a second closure
    /// parameter would make the trailing-closure syntax at every other call
    /// site ambiguous.
    private func stepBody(title: String, hint: String, hintIsError: Bool,
                          @ViewBuilder _ control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 27, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            control()
                .padding(.top, 26)

            Text(hint)
                .font(.system(size: 13.5, weight: hintIsError ? .semibold : .regular))
                .foregroundStyle(hintIsError ? Color.twAccentInk : Color.twInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .animation(.easeInOut(duration: 0.2), value: hintIsError)
        }
    }

    // MARK: - Values

    private var trimmedFirst: String { firstName.trimmingCharacters(in: .whitespaces) }
    private var trimmedCity: String { city.trimmingCharacters(in: .whitespaces) }

    private var composedName: String {
        [trimmedFirst, lastName.trimmingCharacters(in: .whitespaces)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var initials: String {
        let letters = composedName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "·" : String(letters).uppercased()
    }

    /// X6: "Chennai · 1:41 AM · Sep 13" — only the parts we actually know.
    private var metaLine: String {
        var parts: [String] = []
        if !trimmedCity.isEmpty { parts.append(trimmedCity) }
        if let tz = TimeZone(identifier: timezoneId) {
            // `.timeZone(_:)` on the format style adds a zone *symbol*; rendering
            // the clock in that zone means setting the style's own timeZone.
            var clock = Date.FormatStyle.dateTime.hour().minute()
            clock.timeZone = tz
            parts.append(Date().formatted(clock))
        }
        if let birthday {
            parts.append(birthday.formatted(.dateTime.month(.abbreviated).day()))
        }
        return parts.joined(separator: " · ")
    }

    private var isOldEnough: Bool {
        guard let birthday else { return true }   // not set is not "too young"
        guard let cutoff = Calendar.current.date(byAdding: .year, value: -Self.minimumAge, to: Date())
        else { return true }
        return birthday <= cutoff
    }

    /// X10: the typed value matched nothing MapKit knows about.
    private var cityNotFound: Bool {
        !trimmedCity.isEmpty
            && !cities.results.contains { $0.city.caseInsensitiveCompare(trimmedCity) == .orderedSame }
            && !cities.isSearching
    }

    private static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    private static func daysUntilNextBirthday(_ birthday: Date) -> Int? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.month, .day], from: birthday)
        comps.year = cal.component(.year, from: today)
        guard var next = cal.date(from: comps) else { return nil }
        if next < today {
            next = cal.date(byAdding: .year, value: 1, to: next) ?? next
        }
        return cal.dateComponents([.day], from: today, to: next).day
    }

    // MARK: - Actions

    private func prefill() {
        let existing = couple.currentUser
        if firstName.isEmpty {
            // Split whatever name we already hold — from Apple, or from a
            // profile created before this flow existed.
            if !existing.firstName.isEmpty {
                firstName = existing.firstName
                lastName = existing.lastName
            } else {
                let source = existing.displayName.isEmpty ? auth.displayName : existing.displayName
                let parts = source.split(separator: " ", maxSplits: 1).map(String.init)
                firstName = parts.first ?? ""
                lastName = parts.count > 1 ? parts[1] : ""
            }
        }
        if birthday == nil { birthday = existing.birthday }
        if city.isEmpty { city = existing.city ?? "" }
        if bio.isEmpty { bio = existing.bio ?? "" }
        if let tz = existing.timezoneIdentifier { timezoneId = tz }
        fieldFocused = true
    }

    private func choose(_ item: CitySearch.Result) {
        city = item.city
        cities.clear()
        showValidation = false
        fieldFocused = false
        // The completer only knows names. Resolving the time zone needs a real
        // search, so it runs once here rather than per keystroke — and the field
        // is already filled, so a slow answer costs the user nothing.
        Task {
            if let tz = await CitySearch.timeZone(for: item.completion) {
                timezoneId = tz
            }
        }
    }

    private func back() {
        showValidation = false
        withAnimation { step -= 1 }
    }

    private func advance() {
        // Steps that can fail validation report it rather than silently refusing.
        switch step {
        case 0 where firstNameError != nil,
             1 where lastName.count > Self.nameLimit,
             2 where !isOldEnough:
            showValidation = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        case 3 where cityNotFound:
            // X10 offers the correction instead of blocking outright: if MapKit
            // has a suggestion, show it; if it has none, let the typed value
            // stand rather than trapping someone in a village it doesn't know.
            if !cities.results.isEmpty {
                showValidation = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
        case 4 where bio.count > Self.bioLimit:
            showValidation = true
            return
        default:
            break
        }

        showValidation = false

        if step < Self.stepCount - 1 {
            fieldFocused = false
            withAnimation { step += 1 }
            // The last step is a summary, not a question — no keyboard.
            if step < Self.stepCount - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
            }
        } else {
            finish()
        }
    }

    /// The comp's X12/X13 "save failed" screens are not built, and deliberately:
    /// this save is a local UserDefaults write that cannot fail. The name does
    /// reach the partner over the network, but `pushMyNameToSpace` is
    /// fire-and-forget and re-syncs on the next connection, so a failure screen
    /// here would be theatre. If the profile ever moves to a blocking remote
    /// write, X13 is the screen to build.
    private func finish() {
        couple.updateProfile(firstName: trimmedFirst,
                             lastName: lastName,
                             birthday: birthday,
                             city: trimmedCity.isEmpty ? nil : trimmedCity,
                             timezoneIdentifier: timezoneId,
                             bio: bio,
                             photoData: couple.currentUser.photoData)
        app.pushMyProfileToSpace()
        app.finishAboutYou()
    }
}

// MARK: - The big single-line field

/// The comp's input is not a boxed form field — it is a large line of type with
/// a rule under it, so the answer looks like handwriting rather than data entry.
private struct BigField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 30, weight: .heavy))
            .tracking(-0.5)
            .foregroundStyle(Color.twInk)
            .tint(Color.twAccent)
            .autocorrectionDisabled()
            .focused($focused)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(focused ? Color.twAccent : Color.twInk.opacity(0.18))
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: focused)
            }
    }
}

// MARK: - City search

/// Live city suggestions (comp X4). `MKLocalSearchCompleter` gives names as you
/// type; the time zone only arrives with a full `MKLocalSearch`, so that runs
/// once on selection rather than for every keystroke — the completer fires on
/// every character and geocoding each result would be both slow and rude to the
/// rate limiter.
@MainActor
final class CitySearch: NSObject, ObservableObject {

    struct Result: Identifiable {
        let id = UUID()
        let city: String
        let subtitle: String
        let completion: MKLocalSearchCompletion
    }

    /// Resolve one suggestion to an IANA time-zone identifier. `MKMapItem`
    /// carries the zone directly, which avoids a second geocoding round-trip —
    /// and avoids `CLGeocoder`, deprecated in iOS 26.
    static func timeZone(for completion: MKLocalSearchCompletion) async -> String? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        return response.mapItems.first?.timeZone?.identifier
    }

    @Published private(set) var results: [Result] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    func query(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { clear(); return }
        isSearching = true
        completer.queryFragment = trimmed
    }

    func clear() {
        results = []
        isSearching = false
        completer.queryFragment = ""
    }
}

extension CitySearch: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let found = completer.results
        Task { @MainActor in
            self.results = found.prefix(4).map {
                Result(city: $0.title, subtitle: $0.subtitle, completion: $0)
            }
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
            self.isSearching = false
        }
    }
}

// No #Preview: the flow reads four environment objects off the app graph, so a
// bare preview traps on the first missing one. Use TWELI_PROFILE_STEP on the
// simulator instead — that exercises the real graph.
