//
//  ReminderListView.swift
//  Tweli
//
//  Comp L8 (daylight) / N8 (wind down) / B6. The screen is one shared day, not a
//  to-do list: a "Today, together" progress card, then time-of-day groups, then
//  "Done today" faded back. The next reminder due is the only lit thing.
//
//  The comp shows today only. The scope chips are kept (restyled to the comp's
//  chip language) so Upcoming / Repeating / Missed stay reachable — the comp
//  never says those views should disappear, and dropping them would lose data
//  the user has already entered.
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
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                scopeBar
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
            Button { showAdd = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("New").font(.system(size: 13.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.twAccent, in: Capsule())
                .shadow(color: Color.twAccent.opacity(0.35), radius: 11)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.top, 8)
    }

    // MARK: - Scope chips

    private var scopeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Scope.allCases) { s in
                    let on = scope == s
                    Button { withAnimation(.snappy) { scope = s } } label: {
                        Text(s.rawValue)
                            .font(.system(size: 13, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? Color.white : Color.twInkChip)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(on ? Color.twAccent : Color.twElevated,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(on ? .clear : Color.twHairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
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

    private var pending: [ReminderItem] { service.today.filter { !$0.isCompleted } }
    private var done: [ReminderItem] { service.today.filter(\.isCompleted) }

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
            groupCard(items, highlighted: false)
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
