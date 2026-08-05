//
//  VirtualDateRowView.swift
//  Tweli
//
//  A "Later" row from comp L5 / N5: a soft accent tile, the title, one meta line
//  carrying the day and both wall clocks, and a days-away pill when the date is
//  far enough out to be worth counting.
//

import SwiftUI

struct VirtualDateRowView: View {
    let date: VirtualDateItem
    /// The partner's IANA zone, when they've shared a location. `nil` ⇒ the row
    /// shows one clock instead of inventing a second one.
    var partnerTimeZoneId: String? = nil
    var partnerName: String = ""

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.twAccentSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.twAccentInk)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(date.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(DateClocks.metaLine(for: date,
                                         partnerTimeZoneId: partnerTimeZoneId))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            if let days = DateClocks.daysAway(date.date), days >= 2 {
                Text("\(days) days")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.twAccentInk)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.twAccentSoft, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 16)
    }
}

// MARK: - Shared clock formatting

/// The comp shows every date in BOTH wall clocks ("8:00 PM yours · 6:30 PM
/// hers"). We only ever print the second clock when the partner has actually
/// shared a location we can read a time zone from.
enum DateClocks {

    static func clock(_ date: Date, in zone: TimeZone) -> String {
        var fmt = Date.FormatStyle.dateTime.hour().minute()
        fmt.timeZone = zone
        return date.formatted(fmt)
    }

    /// e.g. "Sun, Jul 13 · 8:00 PM yours · 6:30 PM hers"
    static func metaLine(for item: VirtualDateItem, partnerTimeZoneId: String?) -> String {
        let day = item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let mine = clock(item.date, in: .current)
        guard let id = partnerTimeZoneId, let zone = TimeZone(identifier: id),
              zone.identifier != TimeZone.current.identifier else {
            return "\(day) · \(mine)"
        }
        return "\(day) · \(mine) yours · \(clock(item.date, in: zone)) theirs"
    }

    /// Short zone abbreviation for the dual-clock band ("IST", "GST").
    static func abbreviation(_ zone: TimeZone, at date: Date) -> String {
        zone.abbreviation(for: date) ?? zone.identifier
    }

    static func daysAway(_ date: Date) -> Int? {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: date)).day ?? 0
        return days >= 0 ? days : nil
    }

    /// Comp: "Sat, Jul 12 · in 2 days".
    static func heroDateLine(_ date: Date) -> String {
        let day = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        guard let days = daysAway(date) else { return day }
        switch days {
        case 0:  return "\(day) · today"
        case 1:  return "\(day) · tomorrow"
        default: return "\(day) · in \(days) days"
        }
    }
}
