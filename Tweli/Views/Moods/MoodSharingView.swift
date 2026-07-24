//
//  MoodSharingView.swift
//  Tweli
//
//  Design 24a/24b — "Mood composer II", typography-first. No emoji, no faces:
//  the words carry the feeling. A live "what your partner will see" preview sets
//  the chosen mood in large expressive type, chips stage the pick, and a single
//  bottom CTA shares mood + note together. Partner's mood lives on Home, not here.
//

import SwiftUI
import UIKit

struct MoodSharingView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    /// Staged pick — live in the preview, committed only by the Share button.
    @State private var selected: PartnerMood?
    /// Free-text "type your own mood" (designs 24a/b). When non-empty it overrides
    /// the preset label in the preview and is what the partner sees.
    @State private var customMood = ""
    @State private var message = ""
    @State private var justShared = false
    @FocusState private var messageFocused: Bool
    @FocusState private var customFocused: Bool

    /// Keeps the message short enough to sit comfortably on the widget.
    private let messageLimit = 80
    /// A typed mood is a headline, not a sentence — keep it short so it fits the
    /// large preview type and the partner's home card.
    private let customLimit = 24

    private var partnerName: String { app.partner?.displayName ?? "Your partner" }

    /// The preset mood backing the pick — drives tint / the stored `mood` enum even
    /// when a custom label is shown.
    private var previewMood: PartnerMood { selected ?? service.myMood?.mood ?? .missingYou }

    private var trimmedCustom: String { customMood.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What the "partner will see" preview shows: the typed mood if present, else
    /// the selected preset's label.
    private var previewLabel: String { trimmedCustom.isEmpty ? previewMood.label : trimmedCustom }

    private var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                previewCard.padding(.top, 26)
                chipSection
                noteSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { shareBar }
        .onAppear {
            if selected == nil { selected = service.myMood?.mood }
            if customMood.isEmpty, let existing = service.myMood?.customText { customMood = existing }
            if message.isEmpty, let existing = service.myMood?.note { message = existing }
            if app.focusMoodMessage { messageFocused = true; app.focusMoodMessage = false }
        }
        .onChange(of: app.focusMoodMessage) { _, focus in
            if focus { messageFocused = true; app.focusMoodMessage = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOODS")
                .font(.system(size: 12, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Brand.pink)
            Text("How are you\nfeeling?")
                .font(.system(size: 33, weight: .heavy))
                .kerning(-0.8)
                .lineSpacing(1)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - "Partner will see" live preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(partnerName.uppercased()) WILL SEE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(.tertiary)
                Spacer()
                Circle()
                    .fill(LinearGradient(colors: [Brand.indigoLift, Brand.indigo],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(app.currentUser.initials.isEmpty ? "♡" : app.currentUser.initials)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }

            Text(previewLabel)
                .font(.system(size: 34, weight: .heavy))
                .kerning(-1)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, 20)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.16), value: previewLabel)

            if !trimmedMessage.isEmpty {
                Text("\u{201C}\(trimmedMessage)\u{201D}")
                    .font(.system(size: 14.5))
                    .italic()
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
        }
        .padding(.init(top: 22, leading: 22, bottom: 24, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Feeling chips

    private var chipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHOOSE A FEELING")
                .font(.system(size: 12, weight: .bold))
                .kerning(1)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 2)

            FlowLayout(spacing: 10) {
                ForEach(PartnerMood.allCases) { mood in
                    chip(mood)
                }
            }

            customInput
        }
        .padding(.top, 30)
    }

    /// "Type your own mood…" — a free-text alternative to the preset chips
    /// (designs 24a/b). Typing overrides the preview label and deselects the chips.
    private var customInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.pink)
            TextField("Type your own mood…", text: $customMood)
                .font(.system(size: 15, weight: .semibold))
                .focused($customFocused)
                .submitLabel(.done)
                .onChange(of: customMood) { _, new in
                    if new.count > customLimit { customMood = String(new.prefix(customLimit)) }
                    justShared = false
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                Color.primary.opacity(trimmedCustom.isEmpty ? 0.14 : 0), lineWidth: 1)
        )
        .overlay(
            Capsule().strokeBorder(
                Brand.pink.opacity(trimmedCustom.isEmpty ? 0 : 0.9), lineWidth: 1.5)
        )
    }

    private func chip(_ mood: PartnerMood) -> some View {
        // A typed custom mood takes over — the chips visually deselect.
        let on = trimmedCustom.isEmpty && previewMood == mood
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selected = mood
                customMood = ""          // preset replaces any typed mood
            }
            customFocused = false
            justShared = false
        } label: {
            Text(mood.label)
                .font(.system(size: 14.5, weight: on ? .bold : .semibold))
                .foregroundStyle(on ? .white : Color.primary.opacity(0.72))
                .padding(.horizontal, 17).padding(.vertical, 11)
                .background(on ? Brand.pink : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(on ? 0 : 0.18), lineWidth: 1))
                .shadow(color: on ? Brand.pink.opacity(0.4) : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ADD A NOTE (OPTIONAL)")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(message.count) / \(messageLimit) characters")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(message.count >= messageLimit ? Brand.pink : Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 2)

            TextField("Say a little more…", text: $message, axis: .vertical)
                .font(.system(size: 15.5))
                .lineLimit(1...3)
                .focused($messageFocused)
                .onChange(of: message) { _, new in
                    if new.count > messageLimit { message = String(new.prefix(messageLimit)) }
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 30)
    }

    // MARK: - Share CTA (pinned)

    private var shareBar: some View {
        VStack(spacing: 11) {
            Button {
                share()
            } label: {
                Text(justShared ? "Shared ♡" : "Share with \(partnerName)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Brand.pink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Brand.pink.opacity(0.42), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Text("Updates instantly on their home widget")
                .font(.system(size: 12.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color(UIColor.systemGroupedBackground).opacity(0.94))
    }

    private func share() {
        let mood = previewMood
        service.setMyMood(mood,
                          customText: trimmedCustom.isEmpty ? nil : trimmedCustom,
                          note: trimmedMessage.isEmpty ? nil : trimmedMessage)
        messageFocused = false
        customFocused = false
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
