//
//  MoodSharingView.swift
//  Tweli
//
//  Comp U1 — "Moods, U1 locked as canon". The preview card IS the input: you
//  type your feeling straight into the big type your partner will read, with
//  the optional line sharing the same card underneath a hairline. The chips
//  below are shortcuts into that same field, led by "Your own".
//
//  This replaces the earlier L4/N4 arrangement, which had a read-only preview
//  card, a separate "type your own mood" field, and a separate note section —
//  three places to look for one sentence.
//

import SwiftUI
import UIKit

struct MoodSharingView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    /// The feeling itself — always what the big field holds and what the partner
    /// will read. A chip writes into it; typing edits it directly.
    @State private var moodText = ""
    /// Set while the text came from a chip. Typing clears it, which is what makes
    /// the entry a custom mood rather than a preset.
    @State private var selected: PartnerMood?
    @State private var message = ""
    @State private var justShared = false

    @FocusState private var moodFocused: Bool
    @FocusState private var messageFocused: Bool

    /// Keeps the note short enough to sit comfortably on the widget.
    private let messageLimit = 80
    /// A mood is a headline, not a sentence — short enough for the big type and
    /// the partner's home card.
    private let moodLimit = 32

    /// Sentence-initial ("Anaya will see" / "Your partner will see").
    private var partnerName: String { app.partner?.displayName ?? "Your partner" }
    /// Mid-sentence ("Send to Anaya" / "Send to your partner").
    private var partnerNameInline: String { app.partner?.displayName ?? "your partner" }

    private var trimmedMood: String { moodText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Send is only possible once there's a feeling to send.
    private var canSend: Bool { !trimmedMood.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    composerCard.padding(.top, 20)
                    sectionLabel("Or pick one")
                    chips
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                // Room for the pinned CTA.
                .padding(.bottom, 130)
            }
            .scrollDismissesKeyboard(.interactively)

            sendBar
        }
        .background(Color.twBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Restore whatever we last shared so the screen reflects reality.
            if moodText.isEmpty {
                if let existing = service.myMood?.customText, !existing.isEmpty {
                    moodText = existing
                } else if let mood = service.myMood?.mood {
                    moodText = mood.label
                    selected = mood
                }
            }
            if message.isEmpty, let existing = service.myMood?.note { message = existing }
            if app.focusMoodMessage { messageFocused = true; app.focusMoodMessage = false }
        }
        .onChange(of: app.focusMoodMessage) { _, focus in
            if focus { messageFocused = true; app.focusMoodMessage = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Moods")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.twAccentInk)
            Text("How are you feeling?")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - The composer card (the input itself)

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(partnerName) will see")
                    .font(.system(size: 10.5, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Circle()
                    .fill(TweliGradient.meAvatar)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Text(app.currentUser.initials.isEmpty ? "♡" : app.currentUser.initials)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }

            // The feeling — typed directly, not previewed.
            TextField("", text: $moodText, axis: .vertical)
                .font(.system(size: 27, weight: .heavy))
                .tracking(-0.4)
                .lineSpacing(2)
                .foregroundStyle(Color.twInk)
                .tint(Color.twAccentInk)          // the comp's pink caret
                .focused($moodFocused)
                .lineLimit(1...3)
                .padding(.top, 14)
                .overlay(alignment: .topLeading) {
                    if moodText.isEmpty {
                        Text("Say it your way…")
                            .font(.system(size: 27, weight: .heavy))
                            .tracking(-0.4)
                            .foregroundStyle(Color.twInkQuaternary)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: moodText) { _, new in
                    if new.count > moodLimit { moodText = String(new.prefix(moodLimit)) }
                    // Typing over a chip's text makes it your own words again.
                    if let s = selected, new != s.label { selected = nil }
                    justShared = false
                }

            Rectangle()
                .fill(Color.twSeparator)
                .frame(height: 1)
                .padding(.top, 12)

            HStack(alignment: .firstTextBaseline) {
                TextField("add a line…", text: $message, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.twInkSecondary)
                    .tint(Color.twAccentInk)
                    .focused($messageFocused)
                    .lineLimit(1...3)
                    .onChange(of: message) { _, new in
                        if new.count > messageLimit { message = String(new.prefix(messageLimit)) }
                    }
                Text("\(message.count)/\(messageLimit)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.twInkQuaternary)
                    .monospacedDigit()
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            shape.fill(LinearGradient(colors: [.twElevatedWarm, .twElevated],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { shape.strokeBorder(Color.twAccentLight.opacity(0.25), lineWidth: 1) }
                .shadow(color: Color.twAccent.opacity(0.1), radius: 20)
        }
        .contentShape(Rectangle())
        .onTapGesture { moodFocused = true }
    }

    // MARK: - Chips

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, 22)
            .padding(.bottom, 10)
    }

    private var chips: some View {
        FlowLayout(spacing: 8) {
            ownChip
            ForEach(PartnerMood.allCases) { chip($0) }
        }
    }

    /// Comp U1's first chip. Selected whenever the text isn't a preset — which is
    /// exactly when the words are the user's own.
    private var ownChip: some View {
        let on = selected == nil && !trimmedMood.isEmpty
        return Button {
            selected = nil
            moodFocused = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "pencil").font(.system(size: 11, weight: .bold))
                Text("Your own").font(.system(size: 13.5, weight: on ? .bold : .semibold))
            }
            .foregroundStyle(on ? Color.twAccentInk : Color.twInkSecondary)
            .padding(.horizontal, 15).padding(.vertical, 8)
            .background(on ? Color.twAccentSoft : Color.twElevated, in: Capsule())
            .overlay {
                Capsule().strokeBorder(on ? Color.twAccentLight.opacity(0.5) : .clear,
                                       lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func chip(_ mood: PartnerMood) -> some View {
        let on = selected == mood
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selected = mood
                moodText = mood.label
            }
            moodFocused = false
            justShared = false
        } label: {
            Text(mood.label)
                .font(.system(size: 13.5, weight: on ? .bold : .semibold))
                .foregroundStyle(on ? Color.white : Color.twInkSecondary)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(on ? Color.twAccent : Color.twElevated, in: Capsule())
                .shadow(color: on ? Color.twAccent.opacity(0.35) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Send (pinned)

    private var sendBar: some View {
        VStack(spacing: 9) {
            Button { share() } label: {
                Text(justShared ? "Shared ♡" : "Send to \(partnerNameInline)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        // Comp U1: a horizontal indigo → pink sweep.
                        LinearGradient(colors: [Color(UIColor.tw(0x7B79FF)),
                                                Color(UIColor.tw(0xFF375F))],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: Color.twAccent.opacity(0.35), radius: 14)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)

            Text("Updates instantly on their home widget")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.twInkTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [Color.twBackground.opacity(0), Color.twBackground],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func share() {
        guard canSend else { return }
        // A preset chip stores its enum; free text stores the words alongside a
        // backing enum so the widget and Home card still have something typed.
        let mood = selected ?? service.myMood?.mood ?? PartnerMood.allCases[0]
        service.setMyMood(mood,
                          customText: selected == nil ? trimmedMood : nil,
                          note: trimmedMessage.isEmpty ? nil : trimmedMessage)
        moodFocused = false
        messageFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy) { justShared = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { justShared = false }
        }
    }
}

/// Lightweight wrapping layout (flex-wrap) for the mood chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
