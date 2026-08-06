//
//  DatesSheetView.swift
//  Tweli
//
//  Comp L5 / N5 / B3 — "Dates", presented as the half-sheet opened from the
//  "Dates" card on Home. "Next up" is a hero card carrying both wall clocks and
//  its own two actions; everything after it is a quiet "Later" list.
//
//  Both timezones, always — but only when we actually know the partner's zone
//  (it arrives with their shared location). We never print a made-up clock.
//

import SwiftUI

struct DatesSheetView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: VirtualDateService
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false

    private var partnerZoneId: String? { app.partnerTimeZoneId }
    private var partnerName: String { app.partner?.displayName ?? "Your partner" }

    /// Everything planned after the next one.
    private var later: [VirtualDateItem] {
        guard let next = service.next else { return service.planned }
        return service.planned.filter { $0.id != next.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if service.planned.isEmpty {
                        emptyState
                    } else {
                        if let next = service.next {
                            sectionLabel("Next up", top: 24)
                            heroCard(next)
                        }
                        if !later.isEmpty {
                            sectionLabel("Later", top: 24)
                            VStack(spacing: 8) {
                                ForEach(later) { date in
                                    NavigationLink(value: date) {
                                        VirtualDateRowView(date: date,
                                                           partnerTimeZoneId: partnerZoneId,
                                                           partnerName: partnerName)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Mark completed") { service.setStatus(date, .completed) }
                                        Button("Cancel date", role: .destructive) {
                                            service.setStatus(date, .cancelled)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: VirtualDateItem.self) { VirtualDateDetailView(date: $0) }
            .sheet(isPresented: $showAdd) { AddVirtualDateView() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Dates")
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
            Spacer()
            Button { showAdd = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("Plan a date").font(.system(size: 13.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.twAccent, in: Capsule())
                .shadow(color: Color.twAccent.opacity(0.35), radius: 11)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.top, 14)
    }

    private func sectionLabel(_ text: String, top: CGFloat) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, top)
            .padding(.bottom, 10)
    }

    // MARK: - "Next up" hero

    private func heroCard(_ date: VirtualDateItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: date) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.twAccent.opacity(0.16))
                            .frame(width: 52, height: 52)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(Color.twAccentInk)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(date.title)
                            .font(.system(size: 19, weight: .heavy))
                            .tracking(-0.3)
                            .foregroundStyle(Color.twInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(DateClocks.heroDateLine(date.date))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.twAccentInk)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            clockBand(date).padding(.top, 16)
            actionRow(date).padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 22, hero: true)
    }

    /// "You · IST 9:00 PM  →  Anaya · GST 7:30 PM". Collapses to a single clock
    /// when we don't know the partner's zone yet.
    private func clockBand(_ date: VirtualDateItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("You · \(DateClocks.abbreviation(.current, at: date.date))")
                    .font(.system(size: 10.5, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Color.twInkTertiary)
                Text(DateClocks.clock(date.date, in: .current))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.twInk)
            }
            if let zone = partnerZone(for: date) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.twInkTertiary)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(partnerName) · \(DateClocks.abbreviation(zone, at: date.date))")
                        .font(.system(size: 10.5, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(Color.twAccent2)
                        .lineLimit(1)
                    Text(DateClocks.clock(date.date, in: zone))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.twInk)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.twInkTertiary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Only shown when the partner's zone genuinely differs from ours.
    private func partnerZone(for date: VirtualDateItem) -> TimeZone? {
        guard let id = partnerZoneId, let zone = TimeZone(identifier: id),
              zone.identifier != TimeZone.current.identifier else { return nil }
        return zone
    }

    private func actionRow(_ date: VirtualDateItem) -> some View {
        HStack(spacing: 9) {
            Button { service.toggleReminder(date) } label: {
                Text(date.reminderEnabled ? "Reminder on" : "Remind us")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.twAccentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.twAccent.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            // "Reschedule" opens the date's own screen, which owns editing.
            NavigationLink(value: date) {
                Text("Reschedule")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.twInkTertiary.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(Color.twAccentSoft).frame(width: 64, height: 64)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 25))
                    .foregroundStyle(Color.twAccentInk)
            }
            .padding(.bottom, 4)

            Text("No dates planned")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.twInk)
            Text("Pick a time that works in both your days — a film, the same dinner, a call you both look forward to.")
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { showAdd = true } label: {
                Text("Plan the first date")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Brand.cta(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.twAccent.opacity(0.32), radius: 15)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 10)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 20)
        .padding(.top, 26)
    }
}
