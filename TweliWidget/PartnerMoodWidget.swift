//
//  PartnerMoodWidget.swift
//  TweliWidget
//

import WidgetKit
import SwiftUI

struct PartnerMoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliMood", provider: TweliProvider()) { entry in
            PartnerMoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner mood")
        .description("How your partner is feeling right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PartnerMoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(s.partnerName.uppercased()) FEELS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(UIColor.systemPink))
            HStack(spacing: 8) {
                Text(s.partnerMoodEmoji).font(.system(size: family == .systemMedium ? 34 : 26))
                Text(s.partnerMood)
                    .font(.system(size: family == .systemMedium ? 24 : 18, weight: .heavy))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Text("\(s.daysUntil) days until you meet")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}
