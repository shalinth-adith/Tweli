//
//  DatesCardView.swift
//  Tweli
//
//  The "Dates" card on Home (designs 21a/b): a calendar tile + the next planned
//  virtual date and how soon it is. "Open all" (and tapping the card) opens the
//  Dates half-sheet to add/manage dates. With nothing planned yet it becomes a
//  gentle prompt to plan one.
//

import SwiftUI

struct DatesCardView: View {
    /// The soonest upcoming planned date, or `nil` if none is planned.
    let next: VirtualDateItem?
    /// Open the Dates tab.
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dates").tweliEyebrow()
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Open all")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.twAccent)
                }

                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.twAccent.opacity(0.12))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.twAccent)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(next?.title ?? "Plan your first date")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.twInk)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(next == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.twAccent))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// "Sat, Jul 12 · in 2 days" — the date plus a friendly relative distance.
    private var subtitle: String {
        guard let date = next?.date else { return "Tap to plan a date together" }
        let day = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(relativeDay(date))"
    }

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: date)).day ?? 0
        if days < 0 { return "past" }
        return "in \(days) days"
    }
}
