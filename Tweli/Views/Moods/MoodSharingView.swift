//
//  MoodSharingView.swift
//  Tweli
//
//  Partner's mood meter + your own mood meter (both tap into a detail view),
//  and a "How are you feeling?" chip picker that updates your meter live.
//

import SwiftUI

struct MoodSharingView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    @State private var message = ""
    @FocusState private var messageFocused: Bool

    /// Keeps the message short enough to sit comfortably on the widget.
    private let messageLimit = 80

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink(value: MoodTarget.partner) {
                    meter(title: "\(app.partner?.displayName ?? "Partner")'s mood",
                          initials: app.partner?.initials ?? "A",
                          background: .twAccentSoft, accent: .twAccent,
                          mood: service.partnerMood?.mood,
                          updated: service.partnerMood?.relativeLabel,
                          week: service.partnerWeekMoods)
                }
                .buttonStyle(.plain)

                NavigationLink(value: MoodTarget.me) {
                    meter(title: "Your mood",
                          initials: app.currentUser.initials,
                          background: .twAccent2Soft, accent: .twAccent2,
                          mood: service.myMood?.mood,
                          updated: service.myMood?.relativeLabel,
                          week: service.myWeekMoods)
                }
                .buttonStyle(.plain)

                feelingSection
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Moods")
        .navigationDestination(for: MoodTarget.self) { MoodDetailView(target: $0) }
        .onAppear {
            if message.isEmpty, let existing = service.myMood?.note { message = existing }
            if app.focusMoodMessage { messageFocused = true; app.focusMoodMessage = false }
        }
        .onChange(of: app.focusMoodMessage) { _, focus in
            if focus { messageFocused = true; app.focusMoodMessage = false }
        }
    }

    // MARK: - Reusable mood meter card

    private func meter(title: String, initials: String, background: Color, accent: Color,
                       mood: PartnerMood?, updated: String?, week: [PartnerMood]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle().fill(accent).frame(width: 44, height: 44)
                    .overlay(Text(initials).font(.headline).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).tweliEyebrow(accent)
                    Text(mood?.label ?? "Not set")
                        .font(.system(size: 21, weight: .heavy)).foregroundStyle(.primary)
                }
                Spacer()
                Text(mood?.emoji ?? "💗").font(.title2)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, m in
                    Capsule().fill(m.tint).frame(height: 5).frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("Last 7 days").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text(updated.map { "updated \($0)" } ?? "tap for detail")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - "How are you feeling?" chips

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?").font(.headline).foregroundStyle(.primary)

            // Custom message — travels with your mood and sits on your partner's widget.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.bubble.fill").foregroundStyle(Color.twAccent2)
                        .padding(.top, 2)
                    TextField("Add a message for \(app.partner?.displayName ?? "your partner")…",
                              text: $message, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($messageFocused)
                        .onChange(of: message) { _, new in
                            if new.count > messageLimit { message = String(new.prefix(messageLimit)) }
                        }
                }
                .padding(14)
                .background(Color.twElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Text("Shows on \(app.partner?.displayName ?? "your partner")'s widget")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(message.count)/\(messageLimit)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(message.count >= messageLimit ? Color.twWarn : Color.twInkTertiary)
                }
            }

            FlowLayout(spacing: 10) {
                ForEach(PartnerMood.allCases) { mood in
                    moodChip(mood)
                }
            }
            Text("Pick a mood to share it — along with your message.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func moodChip(_ mood: PartnerMood) -> some View {
        let selected = service.myMood?.mood == mood
        return Button {
            let note = message.trimmingCharacters(in: .whitespacesAndNewlines)
            withAnimation(.snappy) { service.setMyMood(mood, note: note.isEmpty ? nil : note) }
            messageFocused = false
        } label: {
            HStack(spacing: 5) {
                if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                Text(mood.label).font(.subheadline.weight(selected ? .bold : .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(selected ? .white : Color.twInk)
            .background(selected ? Color.twAccent : Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: selected ? Color.twAccent.opacity(0.35) : .black.opacity(0.05),
                    radius: selected ? 8 : 4, x: 0, y: selected ? 4 : 1)
        }
        .buttonStyle(.plain)
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
