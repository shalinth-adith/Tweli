//
//  LastPingWidget.swift
//  TweliWidget
//
//  Shows the most recent missing-you ping. Sending a ping in the app refreshes
//  the App Group snapshot and reloads this widget, so it reflects immediately.
//

import WidgetKit
import SwiftUI

struct LastPingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliLastPing", provider: TweliProvider()) { entry in
            LastPingWidgetView(entry: entry)
        }
        .configurationDisplayName("Missing you")
        .description("The latest little love you've shared.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LastPingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private let accent = Color(UIColor.systemPink)

    private var fromLabel: String {
        s.lastPingFrom == "You" ? "You sent" : "From \(s.lastPingFrom)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 10 : 6) {
            HStack {
                Text("MISSING YOU")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: family == .systemMedium ? 15 : 12))
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 0)
            Text(s.lastPingMessage)
                .font(.system(size: family == .systemMedium ? 20 : 16, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(family == .systemMedium ? 2 : 3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text(fromLabel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                if !s.lastPingWhen.isEmpty {
                    Text("· \(s.lastPingWhen)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { accent.opacity(0.12) }
    }
}
