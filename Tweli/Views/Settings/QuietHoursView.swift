//
//  QuietHoursView.swift
//  Tweli
//
//  Comp L14 / N14 — "Quiet hours". The client half of the logic that already
//  lives in functions/index.js: when it is night where your partner is, a push
//  is delivered with `interruption-level: passive` and no sound, so the banner
//  waits on their lock screen instead of waking them.
//
//  One deliberate wording change from the comp. The comp's list is headed "Held
//  for morning" and its rows say "Delivers 7:00 AM her time", which describes a
//  server-side hold-and-release queue. The backend does not do that — it
//  delivers immediately and silently. So the copy here says what actually
//  happens ("Arrived silently"), rather than promising a queue that does not
//  exist. Everything else follows the comp.
//
//  The window (22:00–07:59 recipient-local) is QUIET_START / QUIET_END in
//  functions/index.js; keep the two in step.
//

import SwiftUI

struct QuietHoursView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var pings: MissingYouService
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss

    /// Must match QUIET_START / QUIET_END in functions/index.js.
    private static let quietStartHour = 22
    private static let quietEndHour = 8

    private var partnerName: String { app.partner?.displayName ?? "Your partner" }
    private var partnerZone: TimeZone? {
        app.partnerTimeZone
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    windowCard
                    if quietItems.isEmpty {
                        emptyNote
                    } else {
                        sectionLabel("Waiting for their morning")
                        group
                    }
                    breakthroughNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .navigationTitle("Quiet hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.twInk)
                            .frame(width: 34, height: 34)
                            .background(Color.twInkTertiary.opacity(0.22), in: Circle())
                    }
                }
            }
        }
    }

    // MARK: - The window

    private var windowCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.twAccent2.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(partnerName)'s quiet hours")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.twInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(windowLabel)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkSecondary)
                }
                Spacer(minLength: 0)
                if isQuietNow {
                    Text("Now")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.twAccent2Ink)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.twAccent2Soft, in: Capsule())
                }
            }

            Text(explanation)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            shape.fill(LinearGradient(colors: [.twElevated2, .twElevated],
                                      startPoint: .top, endPoint: .bottom))
                .overlay { shape.strokeBorder(Color.twAccent2.opacity(0.22), lineWidth: 1) }
        }
    }

    /// "11:00 PM – 7:00 AM her time", or an honest fallback when we don't yet
    /// know where she is.
    private var windowLabel: String {
        guard partnerZone != nil else {
            // Their device publishes its zone on every sync, so this only shows
            // in the gap before their first sync lands.
            return "Set once \(partnerName)'s phone checks in"
        }
        return "\(hourLabel(Self.quietStartHour)) – \(hourLabel(Self.quietEndHour)) their time"
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var explanation: String {
        "While \(partnerName) sleeps, your moods and nudges arrive silently — no sound, no lit screen. "
        + "They'll be waiting on the lock screen with their morning coffee, never the thing that wakes them."
    }

    /// True when it is currently inside the partner's quiet window.
    private var isQuietNow: Bool {
        guard let zone = partnerZone else { return false }
        return isQuiet(Date(), in: zone)
    }

    private func isQuiet(_ date: Date, in zone: TimeZone) -> Bool {
        var cal = Calendar.current
        cal.timeZone = zone
        let h = cal.component(.hour, from: date)
        return h >= Self.quietStartHour || h < Self.quietEndHour
    }

    // MARK: - What landed quietly

    private struct QuietItem: Identifiable {
        let id: UUID
        let icon: String
        let tint: Color
        let title: String
        let sentAt: Date
    }

    /// Things I sent that landed inside their night — computed from real records
    /// only. Nothing is fabricated, and the list is empty until it isn't.
    private var quietItems: [QuietItem] {
        guard let zone = partnerZone else { return [] }
        let cutoff = Date().addingTimeInterval(-60 * 60 * 24)   // last 24h
        var out: [QuietItem] = []

        if let mine = moods.myMood, mine.updatedAt > cutoff, isQuiet(mine.updatedAt, in: zone) {
            out.append(QuietItem(id: mine.id,
                                 icon: "face.smiling",
                                 tint: .twAccent,
                                 title: "Your mood — “\(mine.displayLabel)”",
                                 sentAt: mine.updatedAt))
        }
        for ping in pings.history
        where ping.sentBy == app.currentUser.id && ping.sentAt > cutoff && isQuiet(ping.sentAt, in: zone) {
            out.append(QuietItem(id: ping.id,
                                 icon: "heart.fill",
                                 tint: .twAccent2,
                                 title: ping.message,
                                 sentAt: ping.sentAt))
        }
        return out.sorted { $0.sentAt > $1.sentAt }
    }

    private var group: some View {
        VStack(spacing: 0) {
            ForEach(Array(quietItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(Color.twSeparator).frame(height: 1)
                }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(item.tint.opacity(0.14)).frame(width: 36, height: 36)
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Color.twInk)
                            .lineLimit(2)
                        Text(deliveryLine(item.sentAt))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.twInkTertiary)
                    }
                    Spacer(minLength: 6)
                    Text("Silent")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.twAccent2Ink)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.twAccent2Soft, in: Capsule())
                }
                .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .tweliCard(radius: 18)
    }

    private func deliveryLine(_ sentAt: Date) -> String {
        guard let zone = partnerZone else { return "Arrived silently" }
        var fmt = Date.FormatStyle.dateTime.hour().minute()
        fmt.timeZone = zone
        return "Arrived silently at \(sentAt.formatted(fmt)) their time"
    }

    private var emptyNote: some View {
        Text(partnerZone == nil
             ? "Once \(partnerName)'s phone checks in, anything you send overnight will land without a sound."
             : "Nothing has landed in their night recently.")
            .font(.system(size: 13.5))
            .lineSpacing(3)
            .foregroundStyle(Color.twInkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)
            .padding(.horizontal, 2)
    }

    // MARK: - Footnote

    private var breakthroughNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.twWarn)
            Text("A phone call always breaks through — quiet hours only ever silence Tweli.")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.twWarnInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.twWarn.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.twWarn.opacity(0.22), lineWidth: 1)
        }
        .padding(.top, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }
}
