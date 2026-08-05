//
//  PartnerLocalTimeBanner.swift
//  Tweli
//
//  The strip directly under the Home header (comp L3 / N3):
//
//      L3  ☀  It's 10:34 AM in Abu Dhabi — Anaya is starting her day.
//      N3  ☾  It's 11:04 PM in Abu Dhabi — Anaya is probably asleep.
//
//  Note the tint is keyed to your PARTNER'S local time of day, not to the app's
//  theme: the comp happens to show morning on the light screen and night on the
//  dark one, but a light-mode user whose partner is asleep still gets the indigo
//  moon treatment. That is the whole point of the component — it is the one
//  place the app tells you where in her day she is.
//
//  Renders nothing until the partner has shared a location with a time zone.
//

import SwiftUI
import Combine

struct PartnerLocalTimeBanner: View {
    let partnerName: String
    /// The partner's city, e.g. "Abu Dhabi, UAE". Only the leading component is
    /// shown ("Abu Dhabi") so the sentence stays short.
    let cityLabel: String?
    /// IANA identifier from the partner's shared location, e.g. "Asia/Dubai".
    let timeZoneId: String?

    /// Ticks once a minute so the clock in the sentence stays honest.
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if let zone = timeZoneId.flatMap(TimeZone.init(identifier:)) {
            let phase = DayPhase(hour: hour(in: zone))
            HStack(spacing: 9) {
                Image(systemName: phase.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(phase.glyph)
                Text(sentence(zone: zone, phase: phase))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(phase.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                // Comp: linear-gradient(120deg, tint@0.14, tint@0.05)
                LinearGradient(colors: [phase.glyph.opacity(0.14), phase.glyph.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(phase.glyph.opacity(0.25), lineWidth: 1)
            }
            .onReceive(tick) { now = $0 }
        }
    }

    // MARK: - Sentence

    private func hour(in zone: TimeZone) -> Int {
        var cal = Calendar.current
        cal.timeZone = zone
        return cal.component(.hour, from: now)
    }

    private func sentence(zone: TimeZone, phase: DayPhase) -> String {
        var fmt = Date.FormatStyle.dateTime.hour().minute()
        fmt.timeZone = zone
        let clock = now.formatted(fmt)
        // "Abu Dhabi, UAE" → "Abu Dhabi". Falls back to the bare clock when the
        // city hasn't been geocoded yet.
        let city = cityLabel?.split(separator: ",").first.map(String.init)
        let place = city.map { " in \($0)" } ?? ""
        return "It's \(clock)\(place) — \(partnerName) \(phase.state)."
    }

    // MARK: - Time of day

    /// Four bands, each with its own tint and its own way of describing her day.
    private enum DayPhase {
        case morning, day, evening, night

        init(hour: Int) {
            switch hour {
            case 5..<11:  self = .morning
            case 11..<17: self = .day
            case 17..<22: self = .evening
            default:      self = .night
            }
        }

        var icon: String {
            switch self {
            case .morning: return "sun.max"
            case .day:     return "sun.max.fill"
            case .evening: return "sunset"
            case .night:   return "moon.stars"
            }
        }

        /// Comp: warm orange by day (#FF9F0A), indigo at night (#7B79FF).
        var glyph: Color {
            switch self {
            case .morning, .day, .evening: return .twWarn
            case .night:                   return .twAccent2
            }
        }

        /// The text is a deeper shade than the glyph so it stays readable on the
        /// pale tint — comp L3 #B96E00, N3 #B9B8FF.
        var ink: Color {
            switch self {
            case .morning, .day, .evening: return .twWarnInk
            case .night:                   return .twAccent2Ink
            }
        }

        var state: String {
            switch self {
            case .morning: return "is starting her day"
            case .day:     return "is in the middle of her day"
            case .evening: return "is winding down"
            case .night:   return "is probably asleep"
            }
        }
    }
}
