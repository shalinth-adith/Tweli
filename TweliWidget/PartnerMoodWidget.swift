//
//  PartnerMoodWidget.swift
//  TweliWidget
//
//  Design 16b — "Two of us": two dots (you + partner) joined by a thread whose
//  heart rides toward the meet-day, the partner's mood as the headline, their
//  custom message quoted beneath, and a "Send love" reply.
//

import WidgetKit
import SwiftUI

struct PartnerMoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliMood", provider: TweliProvider()) { entry in
            PartnerMoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Two of us")
        .description("Your partner's mood and message, with the reunion thread.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PartnerMoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private let accent = Color(UIColor.systemPink)                    // you (left)
    private let accent2 = Color(red: 0.53, green: 0.42, blue: 0.96)   // partner (right)
    private let sendLoveURL = URL(string: "tweli://sendlove")!

    private var isMedium: Bool { family == .systemMedium }
    private var clampedProgress: Double { min(max(s.countdownProgress, 0.08), 0.92) }
    private var partnerInitial: String {
        let letters = s.partnerName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "♥" : String(letters).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 12 : 8) {
            thread
            Spacer(minLength: 0)
            if isMedium {
                HStack(alignment: .bottom, spacing: 14) {
                    moodBlock
                    Spacer(minLength: 0)
                    sendLoveButton
                }
            } else {
                moodBlock
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { accent.opacity(0.08) }
        .widgetURL(sendLoveURL)   // whole-widget tap (esp. small) → Send love
    }

    // MARK: - S ——❤/badge—— A thread

    private var thread: some View {
        HStack(spacing: 0) {
            dot(String(s.userInitial.prefix(2)), accent)
            GeometryReader { geo in
                let x = geo.size.width * clampedProgress
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.22)).frame(height: 1.6)
                    Capsule().fill(accent).frame(width: x, height: 1.6)
                    marker
                        .position(x: min(max(x, 14), geo.size.width - 14), y: geo.size.height / 2)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: isMedium ? 28 : 26)
            dot(partnerInitial, accent2)
        }
    }

    @ViewBuilder private var marker: some View {
        if isMedium {
            Text("\(s.daysUntil) days")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(accent)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1))
        } else {
            Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(accent)
        }
    }

    private func dot(_ text: String, _ color: Color) -> some View {
        let size: CGFloat = isMedium ? 28 : 26
        return Circle().fill(color).frame(width: size, height: size)
            .overlay(Text(text).font(.system(size: isMedium ? 12 : 11, weight: .heavy))
                .foregroundStyle(.white))
    }

    // MARK: - Mood + message

    private var moodBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(s.partnerName.uppercased()) FEELS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent2)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(s.partnerMood)
                .font(.system(size: isMedium ? 24 : 21, weight: .heavy))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            if !s.partnerMoodNote.isEmpty {
                Text("“\(s.partnerMoodNote)”")
                    .font(.system(size: isMedium ? 13 : 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var sendLoveButton: some View {
        Link(destination: sendLoveURL) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill").font(.system(size: 11))
                Text("Send love").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(accent.opacity(0.16)))
        }
    }
}
