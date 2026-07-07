//
//  ReminderDetailView.swift
//  Tweli
//

import SwiftUI

struct ReminderDetailView: View {
    let reminder: ReminderItem
    @EnvironmentObject private var service: ReminderService
    @Environment(\.dismiss) private var dismiss

    /// Always render the freshest copy from the service.
    private var current: ReminderItem {
        service.reminders.first { $0.id == reminder.id } ?? reminder
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !current.note.isEmpty { noteCard }
                detailGrid
                actions
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Reminder")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(current.title)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                ChipView.assignee(current.assignedTo)
                ChipView(text: current.status.label, tint: current.status.tint)
                if current.isRepeating {
                    ChipView(text: current.repeatType.label, systemImage: "repeat", tint: .twInkSecondary)
                }
            }
        }
    }

    private var noteCard: some View {
        CardView(background: .twAccentSoft) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.fill").foregroundStyle(Color.twAccent)
                Text(current.note).font(.callout).foregroundStyle(.primary)
            }
        }
    }

    private var detailGrid: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                detailRow("calendar", "Date & time", current.reminderDate.formatted(date: .abbreviated, time: .shortened))
                Divider().padding(.leading, 48)
                detailRow(current.visibility.sfSymbol, "Visibility", current.visibility.label)
                Divider().padding(.leading, 48)
                detailRow("flag.fill", "Priority", current.priority.label, tint: current.priority.tint)
            }
        }
    }

    private func detailRow(_ icon: String, _ label: String, _ value: String, tint: Color = .twAccent2) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: current.isCompleted ? "Mark as Not Done" : "Mark as Done",
                          systemImage: current.isCompleted ? "arrow.uturn.left" : "checkmark") {
                service.toggleDone(current)
            }
            HStack(spacing: 10) {
                PrimaryButton(title: "Snooze", systemImage: "clock", tint: .twAccent2, filled: false) {
                    service.snooze(current)
                }
                PrimaryButton(title: "Nudge", systemImage: "bell", tint: .twAccent2, filled: false) {
                    service.sendGentleNudge(current)
                }
            }
            PrimaryButton(title: "Delete", systemImage: "trash", tint: .twWarn, filled: false) {
                service.delete(current)
                dismiss()
            }
        }
        .padding(.top, 4)
    }
}
