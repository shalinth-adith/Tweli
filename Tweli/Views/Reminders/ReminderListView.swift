//
//  ReminderListView.swift
//  Tweli
//

import SwiftUI

struct ReminderListView: View {
    @EnvironmentObject private var service: ReminderService

    enum Filter: String, CaseIterable, Identifiable {
        case today = "Today", upcoming = "Upcoming", repeating = "Repeating"
        case completed = "Completed", missed = "Missed"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .today
    @State private var showAdd = false

    private var items: [ReminderItem] {
        switch filter {
        case .today: return service.today
        case .upcoming: return service.upcoming
        case .repeating: return service.repeating
        case .completed: return service.completed
        case .missed: return service.missed
        }
    }

    var body: some View {
        ScrollView {
            filterBar
            if items.isEmpty {
                EmptyStateView(icon: "bell.badge",
                               title: "No reminders yet",
                               subtitle: "Add a small nudge for something important.",
                               actionTitle: "Add Reminder") { showAdd = true }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(items) { r in
                        NavigationLink(value: r) {
                            ReminderRowView(reminder: r) { withAnimation { service.toggleDone(r) } }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TweliMetrics.screenPadding)
                .padding(.top, 4)
            }
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationDestination(for: ReminderItem.self) { ReminderDetailView(reminder: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddReminderView() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    Button { withAnimation(.snappy) { filter = f } } label: {
                        Text(f.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(filter == f ? .white : Color.twInkSecondary)
                            .background(filter == f ? Color.twAccent : Color.twElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, TweliMetrics.screenPadding)
            .padding(.vertical, 8)
        }
    }
}
