//
//  ReminderListView.swift
//  Tweli
//
//  Comp L8 (daylight) / N8 (wind down) / B6. The screen is one shared day, not a
//  to-do list: a "Today, together" progress card, then time-of-day groups, then
//  "Done today" faded back. The next reminder due is the only lit thing.
//
//  Filtering follows comp S1: a "Showing · Today · soonest first" summary that
//  doubles as the trigger for a menu carrying Show (Today / Upcoming /
//  Repeating / Missed, each with its count) and Sort by (Soonest first / By
//  person / By priority). This replaced an earlier chip row.
//

import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: ReminderService

    enum Scope: String, CaseIterable, Identifiable {
        case today = "Today", upcoming = "Upcoming", repeating = "Repeating", missed = "Missed"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .today
    @State private var sort: ReminderService.SortOrder = .soonest
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                showingBar
                if scope == .today { todayBody } else { scopedBody }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ReminderItem.self) { ReminderDetailView(reminder: $0) }
        .sheet(isPresented: $showAdd) { AddReminderView() }
    }

    // MARK: - Header ("Reminders" + the New pill)

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Reminders")
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
            Spacer()
            HStack(spacing: 9) {
                // Comp S1 puts the accent on the FILTER, not on New — the list
                // is the thing you act on most once reminders exist.
                filterMenu {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 37, height: 37)
                        .background(Color.twAccent, in: Circle())
                        .shadow(color: Color.twAccent.opacity(0.45), radius: 9)
                }
                Button { showAdd = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("New").font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(Color.twInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.twInkTertiary.opacity(0.16), in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    // MARK: - "Showing · Today · soonest first" (comp S1)

    /// The summary line doubles as the menu trigger — the comp anchors the menu
    /// under it, so tapping the thing that describes the filter changes it.
    private var showingBar: some View {
        filterMenu {
            HStack(spacing: 7) {
                Text("Showing")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.twInkTertiary)
                HStack(spacing: 5) {
                    Text("\(scope.rawValue) · \(sort.label.lowercased())")
                        .font(.system(size: 12.5, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.twAccentInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Color.twAccentSoft, in: Capsule())
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    /// One menu definition, two triggers (the round button and the summary pill).
    /// The generic is `Trigger`, not `Label` — that name is SwiftUI's own view.
    private func filterMenu<Trigger: View>(@ViewBuilder trigger: () -> Trigger) -> some View {
        Menu {
            Section("Show") {
                ForEach(Scope.allCases) { s in
                    // A count rides along so "Missed (2)" is visible without
                    // switching to it, exactly as the comp shows.
                    let n = count(for: s)
                    let title = n > 0 ? "\(s.rawValue)  (\(n))" : s.rawValue
                    Button {
                        withAnimation(.snappy) { scope = s }
                    } label: {
                        if scope == s {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            }
            Section("Sort by") {
                ForEach(ReminderService.SortOrder.allCases) { o in
                    Button {
                        withAnimation(.snappy) { sort = o }
                    } label: {
                        if sort == o {
                            Label(o.label, systemImage: "checkmark")
                        } else {
                            Text(o.label)
                        }
                    }
                }
            }
        } label: {
            trigger()
        }
        .buttonStyle(.plain)
    }

    private func count(for s: Scope) -> Int {
        switch s {
        case .today:     return service.today.count
        case .upcoming:  return service.upcoming.count
        case .repeating: return service.repeating.count
        case .missed:    return service.missed.count
        }
    }

    // MARK: - Today (the comp's layout)

    @ViewBuilder private var todayBody: some View {
        if service.today.isEmpty {
            emptyToday
        } else {
            progressCard
            if !pending.isEmpty {
                sectionLabel(nextGroupTitle)
                groupCard(pending, highlighted: true)
            }
            if !done.isEmpty {
                sectionLabel("Done today")
                groupCard(done, highlighted: false).opacity(0.75)
            }
        }
    }

    private var pending: [ReminderItem] {
        service.sorted(service.today.filter { !$0.isCompleted }, by: sort)
    }
    private var done: [ReminderItem] {
        service.sorted(service.today.filter(\.isCompleted), by: sort)
    }

    /// Comp: "Today, together · 4 of 5 done", a 7pt thread-gradient bar, and one
    /// sentence about what is left.
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today, together")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.twInk)
                Spacer()
                Text("\(done.count) of \(service.today.count) done")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.twInkTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.twInkTertiary.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(UIColor.tw(0x7B79FF)),
                                                      Color(UIColor.tw(0xFF375F))],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * service.todayProgress))
                        .shadow(color: Color.twAccent.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 7)
            .padding(.top, 11)

            Text(remainingSentence)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.twInkTertiary)
                .padding(.top, 9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 18)
    }

    /// Comp L8 "One thing left in your day." / N8 "…before you sleep."
    private var remainingSentence: String {
        let left = pending.count
        let nightfall = Calendar.current.component(.hour, from: Date()) >= 17
        let when = nightfall ? "before you sleep" : "in your day"
        switch left {
        case 0:  return "That's everything. Nicely done."
        case 1:  return "One thing left \(when)."
        default: return "\(left) things left \(when)."
        }
    }

    /// The comp names this group by the part of the day it belongs to.
    private var nextGroupTitle: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:  return "This morning"
        case 12..<17: return "This afternoon"
        case 17..<21: return "This evening"
        default:      return "Tonight"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }

    /// A group of rows in one card. `highlighted` is the comp's warm wash with a
    /// pink ring, used for the reminders still ahead of you.
    private func groupCard(_ items: [ReminderItem], highlighted: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, r in
                if index > 0 {
                    Rectangle().fill(Color.twSeparator).frame(height: 1)
                }
                NavigationLink(value: r) {
                    ReminderRowView(reminder: r,
                                    isNext: highlighted && index == 0,
                                    ownerInitials: initials(for: r),
                                    ownerIsPartner: isPartners(r)) {
                        withAnimation { service.toggleDone(r) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            if highlighted {
                shape
                    .fill(LinearGradient(colors: [.twElevatedWarm, .twElevated],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { shape.strokeBorder(Color.twAccentLight.opacity(0.3), lineWidth: 1) }
            } else {
                shape.fill(Color.twElevated)
                    .overlay { shape.strokeBorder(Color.twHairline, lineWidth: 1) }
            }
        }
    }

    // MARK: - Other scopes (same rows, plain grouping)

    @ViewBuilder private var scopedBody: some View {
        let items: [ReminderItem] = {
            switch scope {
            case .today:     return service.today
            case .upcoming:  return service.upcoming
            case .repeating: return service.repeating
            case .missed:    return service.missed
            }
        }()
        if items.isEmpty {
            emptyScope
        } else {
            groupCard(service.sorted(items, by: sort), highlighted: false)
        }
    }

    // MARK: - Empty states (comp E7's voice: an invitation, not a void)

    private var emptyToday: some View {
        emptyBlock(title: "Nothing planned today",
                   body: "Add a small nudge — a call to make, a photo to send, a reason to think of each other.",
                   action: "Add the first reminder")
    }

    private var emptyScope: some View {
        emptyBlock(title: "Nothing here yet",
                   body: "Reminders you add will show up in this list.",
                   action: "Add a reminder")
    }

    private func emptyBlock(title: String, body: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 21, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Color.twInk)
            Text(body)
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { showAdd = true } label: {
                Text(action)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Brand.cta(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.twAccent.opacity(0.3), radius: 14)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 18)
        .padding(.top, 4)
    }

    // MARK: - Ownership

    private func isPartners(_ r: ReminderItem) -> Bool {
        r.createdBy != app.currentUser.id
    }

    private func initials(for r: ReminderItem) -> String {
        isPartners(r) ? (app.partner?.initials ?? "") : app.currentUser.initials
    }
}
