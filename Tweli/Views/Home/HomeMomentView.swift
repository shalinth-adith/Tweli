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

    private var remindersCard: some View {
        CardView(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Today").tweliEyebrow()
                    Spacer()
                    if !reminders.today.isEmpty {
                        Text(todayCountLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.twAccent)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

                if reminders.today.isEmpty {
                    Text("No reminders today")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                } else {
                    ForEach(reminders.today.prefix(3)) { r in
                        HStack(spacing: 12) {
                            Button { withAnimation { reminders.toggleDone(r) } } label: {
                                // Curved-square checkbox (design: rounded square,
                                // warn-tinted while the reminder is overdue).
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(r.isCompleted ? .clear
                                                      : (r.isMissed ? Color.twWarn : Color.twInkTertiary),
                                                      lineWidth: 1.8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(r.isCompleted ? Color.twSuccess : .clear)
                                        )
                                        .frame(width: 25, height: 25)
                                    if r.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Text(r.title)
                                .font(.subheadline)
                                .strikethrough(r.isCompleted)
                                .foregroundStyle(r.isCompleted ? .tertiary : .primary)
                            Spacer()
                            Text(r.timeLabel).font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        if r.id != reminders.today.prefix(3).last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                // "Add a reminder" — jumps to the Reminders tab to compose one.
                Button { app.requestedTab = 1 } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("Add a reminder")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.twAccent)
                    .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
    }

    private var todayCountLabel: String {
        let items = reminders.today
        let done = items.filter { $0.isCompleted }.count
        return "\(done)/\(items.count)"
    }
}
