//
//  NextDateWidget.swift
//  TweliWidget
//

import WidgetKit
import SwiftUI

struct NextDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TweliNextDate", provider: TweliProvider()) { entry in
            NextDateWidgetView(entry: entry)
        }
        .configurationDisplayName("Next virtual date")
        .description("Your upcoming date together.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextDateWidgetView: View {
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NEXT DATE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(UIColor.systemIndigo))
                Spacer()
                Image(systemName: "calendar").font(.caption).foregroundStyle(Color(UIColor.systemIndigo))
            }
            Spacer()
            Text(s.nextDateTitle)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
            Text(s.nextDateTime).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}
