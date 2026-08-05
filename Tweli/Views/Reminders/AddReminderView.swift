//
//  AddReminderView.swift
//  Tweli
//
//  Comp R1–R4 — "The New Reminder sheet, designed properly".
//
//    R1  the sheet at rest; Save is dim until there's something to save
//    R2  Save tapped with problems; errors are inline, kind, and specific
//    R3  filled and ready; Save lights up once it has a title
//    R4  Save failed offline; nothing is lost, it saves itself later
//
//  The "Assigned to" segment is the UI for the notification routing rule: Me
//  rings only your phone, your partner's name rings only theirs, Both rings on
//  both (see ReminderService.shouldRing).
//

import SwiftUI

struct AddReminderView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: ReminderService
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddReminderViewModel()

    /// Comp R4 — the save didn't reach the server. The sheet stays open and the
    /// reminder is already on disk, so nothing is lost.
    @State private var savedAsDraft = false

    @FocusState private var titleFocused: Bool

    private var partnerName: String { app.partner?.displayName ?? "Partner" }
    private var myInitials: String { app.currentUser.initials.isEmpty ? "·" : app.currentUser.initials }
    private var partnerInitials: String { app.partner?.initials ?? "·" }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.twSheet.ignoresSafeArea()

            VStack(spacing: 0) {
                grabber
                titleBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleCard
                        if let err = vm.titleError { inlineError(err) }

                        sectionLabel("Assigned to")
                        assigneeSegment

                        sectionLabel("When")
                        whenCard
                        if let err = vm.timeError {
                            inlineError(err)
                        } else if let hint = timezoneHint {
                            hintLine(hint)
                        }

                        sectionLabel("Options")
                        optionsCard

                        Text(footnote)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.twInkQuaternary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, savedAsDraft ? 120 : 30)
                }
            }

            if savedAsDraft { offlineToast }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: savedAsDraft)
        .animation(.easeInOut(duration: 0.2), value: vm.titleError)
        .animation(.easeInOut(duration: 0.2), value: vm.timeError)
    }

    // MARK: - Chrome

    private var grabber: some View {
        Capsule()
            .fill(Color.twInkTertiary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    private var titleBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 16))
                .foregroundStyle(Color.twAccentInk)

            Spacer()
            Text("New Reminder")
                .font(.system(size: 16.5, weight: .bold))
                .foregroundStyle(Color.twInk)
            Spacer()

            Button { save() } label: {
                Text(savedAsDraft ? "Retry" : "Save")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(vm.canSave ? Color.white : Color.twInkQuaternary)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 8)
                    .background(vm.canSave ? Color.twAccent : Color.twInkTertiary.opacity(0.14),
                                in: Capsule())
                    .shadow(color: vm.canSave ? Color.twAccent.opacity(0.35) : .clear,
                            radius: 9, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!vm.canSave)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Title + note

    private var titleCard: some View {
        VStack(spacing: 0) {
            TextField("Reminder title", text: $vm.title)
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(Color.twInk)
                .focused($titleFocused)
                .submitLabel(.next)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)

            Rectangle().fill(Color.twSeparator).frame(height: 1)

            HStack(alignment: .top, spacing: 4) {
                TextField("Add a small note", text: $vm.note, axis: .vertical)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.twInkChip)
                    .lineLimit(1...4)
                Text("♥").font(.system(size: 14.5)).foregroundStyle(Color.twAccentInk)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 15)
        }
        .background(Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            // R2: the whole card takes the error ring, not just the field.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(vm.titleError != nil ? Color.twDanger.opacity(0.65) : Color.twHairline,
                              lineWidth: vm.titleError != nil ? 1 : 0.5)
        }
        .padding(.top, 10)
        .onChange(of: vm.title) { _, _ in vm.clearAttempt() }
    }

    // MARK: - Assigned to (the routing control)

    private var assigneeSegment: some View {
        HStack(spacing: 4) {
            segment(.me, label: "Me") { avatarDot(myInitials, partner: false) }
            segment(.partner, label: partnerName) { avatarDot(partnerInitials, partner: true) }
            segment(.both, label: "Both") {
                // Overlapping pair, per the comp.
                HStack(spacing: -5) {
                    avatarDot(myInitials, partner: false)
                        .overlay(Circle().strokeBorder(Color.twSheet, lineWidth: 1.5))
                        .zIndex(1)
                    avatarDot(partnerInitials, partner: true)
                }
            }
        }
        .padding(5)
        .background(Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 0.5)
        }
    }

    private func segment<Icon: View>(_ value: ReminderAssignee, label: String,
                                     @ViewBuilder icon: () -> Icon) -> some View {
        let on = vm.assignedTo == value
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { vm.assignedTo = value }
        } label: {
            HStack(spacing: 7) {
                icon()
                Text(label)
                    .font(.system(size: 13.5, weight: on ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.white : Color.twInkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Brand.cta())
                        .shadow(color: Color.twAccent.opacity(0.3), radius: 7)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func avatarDot(_ initials: String, partner: Bool) -> some View {
        Circle()
            .fill(partner ? TweliGradient.partnerAvatar : TweliGradient.meAvatar)
            .frame(width: 17, height: 17)
            .overlay {
                Text(initials.prefix(1))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - When

    private var whenCard: some View {
        VStack(spacing: 0) {
            row("Date") {
                DatePicker("", selection: $vm.date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Color.twAccent)
            }
            Rectangle().fill(Color.twSeparator).frame(height: 1)
            row("Time") {
                DatePicker("", selection: $vm.time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Color.twAccent)
            }
            Rectangle().fill(Color.twSeparator).frame(height: 1)
            row("Repeat") {
                Picker("", selection: $vm.repeatType) {
                    ForEach(RepeatType.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(Color.twAccentInk)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(vm.timeError != nil ? Color.twDanger.opacity(0.65) : Color.twHairline,
                              lineWidth: vm.timeError != nil ? 1 : 0.5)
        }
        .onChange(of: vm.date) { _, _ in vm.clearAttempt() }
        .onChange(of: vm.time) { _, _ in vm.clearAttempt() }
        .onChange(of: vm.repeatType) { _, _ in vm.clearAttempt() }
    }

    // MARK: - Options

    private var optionsCard: some View {
        VStack(spacing: 0) {
            row("Visibility") {
                Picker("", selection: $vm.visibility) {
                    ForEach(ReminderVisibility.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).tint(Color.twAccentInk)
            }
            Rectangle().fill(Color.twSeparator).frame(height: 1)
            row("Priority") {
                Picker("", selection: $vm.priority) {
                    ForEach(ReminderPriority.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.menu).tint(Color.twAccentInk)
            }
        }
        .padding(.horizontal, 16)
        .background(Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 0.5)
        }
    }

    private func row<Trailing: View>(_ label: String,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15.5))
                .foregroundStyle(Color.twInk)
            Spacer()
            trailing()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Supporting copy

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 4)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }

    private func inlineError(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(.system(size: 12.5, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.twDangerInk)
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func hintLine(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.twAccent2Ink)
        .padding(.horizontal, 4)
        .padding(.top, 9)
    }

    private var timezoneHint: String? {
        vm.timezoneHint(partnerName: app.partner?.displayName ?? "",
                        partnerTimeZoneId: location.partnerLocation?.timeZoneId,
                        partnerCity: location.partnerLocation?.cityLabel)
    }

    /// Comp R1: "She'll get a gentle nudge, not an alarm." Reworded to say who
    /// will actually be nudged, which depends on the segment above.
    private var footnote: String {
        switch vm.assignedTo {
        case .me:      return "Only you'll be nudged for this one."
        case .partner: return "\(partnerName) will get a gentle nudge, not an alarm."
        case .both:    return "You'll both get a gentle nudge, not an alarm."
        }
    }

    // MARK: - Offline (comp R4)

    private var offlineToast: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.twWarn.opacity(0.14)).frame(width: 34, height: 34)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.twWarn)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("You're offline")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.twInk)
                Text("Saved as a draft — it'll send itself when you're back.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("Draft")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.twWarnInk)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.twWarn.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.twElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 17, y: 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Save

    private func save() {
        guard vm.validate() else { return }
        guard let spaceId = app.coupleSpaceService.coupleSpace?.id else { return }

        let reminder = vm.build(createdBy: app.currentUser.id, coupleSpaceId: spaceId)
        // `add` writes to the local store (and schedules the alert) immediately,
        // then pushes to Firestore. Firestore's offline cache queues the write,
        // so an offline save is genuinely a draft that sends itself — nothing to
        // retry manually, but the sheet says so rather than pretending it synced.
        service.add(reminder)

        if app.cloud.accountAvailable {
            dismiss()
        } else {
            withAnimation { savedAsDraft = true }
        }
    }
}
