//
//  HomeMomentView.swift
//  Tweli
//
//  The Home dashboard (designs 21a/b — light/dark). Top to bottom: the partner's
//  fresh mood (card that collapses to a strip), the blue "closeness" band
//  (distance apart · days together), today's checkable reminders, and the next
//  planned date. The greeting header lives in HomeView.
//

import SwiftUI

struct HomeMomentView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var reminders: ReminderService
    @EnvironmentObject private var countdowns: CountdownService
    @EnvironmentObject private var virtualDates: VirtualDateService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var couple: CoupleSpaceService

    @State private var showMeetSheet = false
    @State private var showDatesSheet = false
    @State private var showDistance = false

    var body: some View {
        VStack(spacing: 12) {
            // "It's 11:04 PM in Abu Dhabi — Anaya is probably asleep." Renders
            // nothing until the partner has shared a location with a time zone.
            if let partner = app.partner {
                PartnerLocalTimeBanner(partnerName: partner.displayName,
                                       cityLabel: location.partnerLocation?.cityLabel,
                                       timeZoneId: location.partnerLocation?.timeZoneId)
            }
            moodMoment
            ClosenessStripView(distanceLabel: location.distanceApartLabel,
                               hasMyLocation: location.myLocation != nil,
                               daysToReunion: reunionDays,
                               onOpenDistance: { showDistance = true },
                               onShareLocation: { location.requestAndCapture() },
                               onSetMeet: { showMeetSheet = true })
            remindersCard
            DatesCardView(next: virtualDates.next) { showDatesSheet = true }   // open the Dates half-sheet
        }
        .sheet(isPresented: $showMeetSheet) { MeetDateSheetView() }
        .sheet(isPresented: $showDatesSheet) { DatesSheetView() }
        .sheet(isPresented: $showDistance) {
            DistanceJourneyView(
                myCity: location.myLocation?.cityLabel ?? "You",
                partnerCity: location.partnerLocation?.cityLabel ?? "Them",
                distanceLabel: location.distanceApartLabel ?? "—",
                daysTogether: daysTogether,
                daysToGo: reunionDays
            )
        }
#if DEBUG
        // Verification hooks: auto-open a sheet so a headless simulator can
        // screenshot it (no touch injection). TWELI_MEET_SHEET=1 → meet sheet;
        // TWELI_DATES_SHEET=1 → Dates half-sheet; TWELI_DISTANCE=1 → distance.
        .onAppear {
            let env = ProcessInfo.processInfo.environment
            if env["TWELI_MEET_SHEET"] == "1" { showMeetSheet = true }
            if env["TWELI_DATES_SHEET"] == "1" { showDatesSheet = true }
            if env["TWELI_DISTANCE"] == "1" { showDistance = true }
        }
#endif
    }

    // MARK: - Partner's mood (static resting card — the swipe lives on the interstitial)

    @ViewBuilder private var moodMoment: some View {
        if let mood = moods.partnerMood {
            // Right-swipe KEEP (designs 22a/b) leaves the prominent card; a left-swipe
            // DISMISS collapses to the quiet strip. A newer mood resets to the card.
            if moods.partnerMoodCollapsed {
                MoodStripView()
            } else {
                FreshMoodCardView(
                    mood: mood,
                    partnerName: app.partner?.displayName ?? "Your partner",
                    partnerInitials: app.partner?.initials ?? "?",
                    onTap: { app.requestedTab = 2 }          // open the Moods tab
                )
            }
        }
    }

    /// Days until the reunion — the pinned "meeting" countdown, else the soonest
    /// pinned one. `nil` ⇒ no meet date set → the strip invites you to set one.
    private var reunionDays: Int? {
        (countdowns.countdowns.first { $0.category == .meeting } ?? countdowns.pinned)?.daysRemaining
    }

    /// Whole days since the couple space began — the "days together" tile.
    private var daysTogether: Int? {
        guard let start = couple.coupleSpace?.createdAt else { return nil }
        let days = Calendar.current.dateComponents([.day],
                                                   from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, days)
    }

    // MARK: - Today's reminders (checkable)

    /// Comp L3 "Sometime today" / N3 "Before you sleep": a quiet card whose
    /// eyebrow names the part of the day, one row per remaining reminder with a
    /// 23pt rounded-square checkbox, and the row's own action in accent ink.
    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(todayEyebrow).tweliEyebrow()
                Spacer()
                if !reminders.today.isEmpty {
                    Text(todayCountLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.twAccentInk)
                }
            }

            if reminders.today.isEmpty {
                Text("Nothing planned today.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.twInkSecondary)
                    .padding(.top, 12)
            } else {
                ForEach(Array(reminders.today.prefix(3).enumerated()), id: \.element.id) { index, r in
                    if index > 0 {
                        Rectangle().fill(Color.twSeparator).frame(height: 1).padding(.leading, 35)
                    }
                    reminderRow(r)
                }
            }

            // "Add a reminder" — jumps to the Reminders tab to compose one.
            Button { app.requestedTab = 1 } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add a reminder")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.twAccentInk)
                .padding(.top, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard()
    }

    private func reminderRow(_ r: ReminderItem) -> some View {
        HStack(spacing: 12) {
            Button { withAnimation { reminders.toggleDone(r) } } label: {
                // Comp: 23pt square, radius 7, 2pt stroke; warn-tinted while overdue.
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(r.isCompleted ? .clear
                                  : (r.isMissed ? Color.twWarn : Color.twControlStroke),
                                  lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(r.isCompleted ? Color.twSuccess : .clear)
                    )
                    .frame(width: 23, height: 23)
                    .overlay {
                        if r.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(r.title)
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(r.isCompleted)
                    .foregroundStyle(r.isCompleted ? Color.twInkTertiary : Color.twInk)
                Text(r.timeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    /// The comp changes this label with the hour: "Sometime today" by day,
    /// "Before you sleep" at night, "This evening" in between.
    private var todayEyebrow: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<5, 21...: return "Before you sleep"
        case 17..<21:      return "This evening"
        default:           return "Sometime today"
        }
    }

    private var todayCountLabel: String {
        let items = reminders.today
        let done = items.filter { $0.isCompleted }.count
        return "\(done) of \(items.count) done"
    }
}
