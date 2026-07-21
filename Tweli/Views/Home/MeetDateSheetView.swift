//
//  MeetDateSheetView.swift
//  Tweli
//
//  The "When do you meet?" half-sheet (designs 21a/b). Opened from the ❤️ N-days
//  chip on the Home mood card. Pick the reunion day on a month calendar and it
//  creates / updates the pinned "meeting" countdown — the same one that drives
//  the chip, the widget, and the day-zero notification.
//

import SwiftUI

struct MeetDateSheetView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var countdowns: CountdownService
    @Environment(\.dismiss) private var dismiss

    /// The first day of the month currently on screen.
    @State private var month: Date = Calendar.current.startOfDay(for: Date())
    @State private var selected: Date?

    private let cal = Calendar.current
    private var today: Date { cal.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
            Text("When do you meet?")
                .font(.system(size: 22, weight: .heavy))
            Text("Pick the day and we'll count it down for you.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            monthHeader.padding(.top, 18).padding(.bottom, 12)
            weekdayHeader
            calendarGrid.padding(.top, 4)

            summaryBar.padding(.top, 16)
            setButton.padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(580)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            // Preselect the existing reunion date so the sheet opens on its month.
            if let existing = meetingCountdown {
                selected = cal.startOfDay(for: existing.targetDate)
                month = existing.targetDate
            }
        }
    }

    // MARK: - Header pieces

    private var grabber: some View {
        Capsule()
            .fill(Color(UIColor.tertiaryLabel))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 16)
    }

    private var monthHeader: some View {
        HStack {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
            }
            .disabled(cal.isDate(month, equalTo: today, toGranularity: .month))
            Button { step(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
            }
            .padding(.leading, 14)
        }
        .foregroundStyle(.primary)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date { dayCell(date) } else { Color.clear.frame(height: 38) }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isPast = date < today
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let isToday = cal.isDate(date, inSameDayAs: today)
        return Button {
            selected = date
        } label: {
            Text("\(cal.component(.day, from: date))")
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .frame(width: 38, height: 38)
                .foregroundStyle(cellForeground(isPast: isPast, isSelected: isSelected, isToday: isToday))
                .background {
                    if isSelected {
                        Circle().fill(Color.twAccent)
                            .shadow(color: Color.twAccent.opacity(0.4), radius: 8, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func cellForeground(isPast: Bool, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isPast { return Color(UIColor.quaternaryLabel) }
        if isToday { return .twAccent }
        return .primary
    }

    // MARK: - Summary + confirm

    private var summaryBar: some View {
        HStack(spacing: 8) {
            Text("❤️").font(.system(size: 16))
            Text(selected == nil ? "Pick a day" : "\(daysToSelected) days to go")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.twAccent)
            Spacer()
            if let selected {
                Text(selected.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.twAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var setButton: some View {
        Button(action: setMeetDate) {
            Text("Set meet date")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(colors: [.twAccent2, .twAccent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.twAccent.opacity(0.3), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(selected == nil)
        .opacity(selected == nil ? 0.5 : 1)
    }

    // MARK: - Data

    private var meetingCountdown: CountdownItem? {
        countdowns.countdowns.first { $0.category == .meeting }
    }

    /// Cells for the displayed month: leading blanks (nil) + each day.
    private var monthCells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday,
              let count = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)   // Sunday = 1
        for d in 0..<count {
            cells.append(cal.date(byAdding: .day, value: d, to: interval.start))
        }
        return cells
    }

    private var daysToSelected: Int {
        guard let selected else { return 0 }
        return max(0, cal.dateComponents([.day], from: today, to: selected).day ?? 0)
    }

    private func step(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = next }
        }
    }

    private func setMeetDate() {
        guard let selected, let spaceId = app.coupleSpaceService.coupleSpace?.id else { return }
        if var existing = meetingCountdown {
            existing.targetDate = selected
            existing.isPinned = true
            countdowns.update(existing)
        } else {
            let item = CountdownItem(title: "Until we meet again",
                                     targetDate: selected,
                                     category: .meeting,
                                     isPinned: true,
                                     createdBy: app.currentUser.id,
                                     coupleSpaceId: spaceId)
            countdowns.add(item)
        }
        dismiss()
    }
}
