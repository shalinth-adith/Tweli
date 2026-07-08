//
//  CountdownWidget.swift
//  TweliWidget
//
//  The primary widget — matches the design's widget gallery (small / medium / large).
//

import WidgetKit
import SwiftUI

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliCountdown", provider: TweliProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days until you meet again.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private let accent = Color(UIColor.systemPink)

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    // Small — pink card with the big day count.
    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("COUNTDOWN").font(.system(size: 10, weight: .semibold)).opacity(0.85)
                Spacer()
                Image(systemName: "heart.fill").font(.system(size: 11)).opacity(0.8)
            }
            Spacer()
            Text("\(s.daysUntil)").font(.system(size: 42, weight: .heavy)).minimumScaleFactor(0.6)
            Text("days to go").font(.system(size: 12, weight: .semibold)).opacity(0.9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { accent }
    }

    // Medium — countdown + next date, split.
    private var medium: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("COUNTDOWN").font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
                Text("\(s.daysUntil) days").font(.system(size: 26, weight: .heavy)).foregroundStyle(.primary)
                Text(s.countdownTitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT DATE").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(UIColor.systemIndigo))
                Text(s.nextDateTitle).font(.subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(1)
                Text(s.nextDateTime).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }

    // Large — countdown headline + mood + next date rows.
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.countdownTitle.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
            Text("\(s.daysUntil) days").font(.system(size: 44, weight: .heavy)).foregroundStyle(.primary)
            Divider()
            row("\(s.partnerName)'s mood", "\(s.partnerMoodEmoji) \(s.partnerMood)")
            Divider()
            row("Next date", s.nextDateTitle)
            Spacer()
            Text("Closer every day \u{2764}\u{FE0F}").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(1)
        }
    }
}
