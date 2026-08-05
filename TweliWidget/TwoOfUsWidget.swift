//
//  TwoOfUsWidget.swift
//  TweliWidget
//
//  Comp C1 / L10 / N10 — "Two of us", the only widget.
//
//      (S)━━━━━━━♥━━━━━(A)          the thread, heart at the countdown's %
//      ANAYA FEELS                   her mood in plain words
//      Missing you          ♥ Send   her message quoted beneath
//      "Wish you were here…"
//
//  The heart sits at the same fraction everywhere in the app: days elapsed of
//  the total wait. Small shows the mood and message; medium adds the day-count
//  pill on the thread and a "Send love" tap target.
//

import WidgetKit
import SwiftUI

struct TwoOfUsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliTwoOfUs", provider: TweliProvider()) { entry in
            TwoOfUsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Two of us")
        .description("Your partner's mood and message, with the reunion thread.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TwoOfUsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var s: WidgetSnapshot { entry.snapshot }
    private var isMedium: Bool { family == .systemMedium }
    private let sendLoveURL = URL(string: "tweli://sendlove")!

    /// Kept off both ends so the heart never collides with a dot.
    private var progress: Double { min(max(s.countdownProgress, 0.08), 0.92) }

    private var partnerInitial: String {
        let letters = s.partnerName.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "♥" : String(letters).uppercased()
    }

    private var myInitial: String {
        let t = s.userInitial.trimmingCharacters(in: .whitespaces)
        return t.isEmpty || t == "You" ? "·" : String(t.prefix(2)).uppercased()
    }

    /// Nothing shared yet — the widget says so rather than inventing a mood.
    private var hasMood: Bool { !s.partnerMood.isEmpty && s.partnerMood != "—" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            threadRow
            Spacer(minLength: 8)
            if isMedium {
                HStack(alignment: .bottom, spacing: 14) {
                    moodBlock
                    sendLove
                }
            } else {
                moodBlock
            }
        }
        .padding(.horizontal, isMedium ? 18 : 15)
        .padding(.vertical, isMedium ? 16 : 15)
        .widgetURL(sendLoveURL)
    }

    // MARK: - The thread

    private var threadRow: some View {
        let dot: CGFloat = isMedium ? 28 : 26
        return HStack(spacing: 0) {
            avatarDot(myInitial, fill: WidgetPalette.me, size: dot)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WidgetPalette.threadTrack)
                        .frame(height: 1.4)
                    Capsule()
                        .fill(WidgetPalette.thread)
                        .frame(width: geo.size.width * progress, height: 1.4)
                    marker
                        .position(x: geo.size.width * progress, y: geo.size.height / 2)
                }
                .frame(height: geo.size.height, alignment: .center)
            }
            .frame(height: dot)
            avatarDot(partnerInitial, fill: WidgetPalette.partner, size: dot)
        }
        .padding(.horizontal, isMedium ? 6 : 0)
        .padding(.top, 2)
    }

    /// Small carries a bare heart; medium carries the day-count pill the comp
    /// puts on the thread ("21 days").
    @ViewBuilder private var marker: some View {
        if isMedium && s.daysUntil > 0 {
            Text(s.daysUntil == 1 ? "1 day" : "\(s.daysUntil) days")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WidgetPalette.actionInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(WidgetPalette.pillFill, in: Capsule())
                .shadow(color: WidgetPalette.thread.opacity(0.35), radius: 5)
                .fixedSize()
        } else {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundStyle(WidgetPalette.thread)
                .shadow(color: WidgetPalette.thread.opacity(0.5), radius: 3)
        }
    }

    private func avatarDot(_ initials: String, fill: Color, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: isMedium ? 12 : 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
            }
            .shadow(color: fill.opacity(0.5), radius: 6)
    }

    // MARK: - The mood

    private var moodBlock: some View {
        VStack(alignment: .leading, spacing: isMedium ? 2 : 4) {
            Text(hasMood ? "\(s.partnerName) feels" : "Two of us")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(WidgetPalette.inkTertiary)
                .lineLimit(1)

            Text(hasMood ? s.partnerMood : "Nothing shared yet")
                .font(.system(size: isMedium ? 24 : 21, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            if hasMood && !s.partnerMoodNote.isEmpty {
                Text("\u{201C}\(s.partnerMoodNote)\u{201D}")
                    .font(.system(size: isMedium ? 13 : 12))
                    .foregroundStyle(WidgetPalette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !hasMood {
                Text("Their mood lands here the moment they share it.")
                    .font(.system(size: isMedium ? 13 : 12))
                    .foregroundStyle(WidgetPalette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Send love (medium only)

    private var sendLove: some View {
        Link(destination: sendLoveURL) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill").font(.system(size: 11))
                Text("Send love").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(WidgetPalette.actionInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(WidgetPalette.actionFill, in: Capsule())
        }
        .fixedSize()
    }
}
