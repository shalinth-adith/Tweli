//
//  VirtualDateDetailView.swift
//  Tweli
//
//  Details for a single planned virtual date — reached by tapping a row (or the
//  "next date" hero) on the Dates screen.
//

import SwiftUI

struct VirtualDateDetailView: View {
    let date: VirtualDateItem
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: VirtualDateService
    @Environment(\.dismiss) private var dismiss

    /// Always render the freshest copy from the service.
    private var current: VirtualDateItem {
        service.dates.first { $0.id == date.id } ?? date
    }

    private var createdByLabel: String {
        current.createdBy == app.currentUser.id ? "You" : (app.partner?.displayName ?? "Your partner")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                if !current.notes.isEmpty { notesCard }
                detailGrid
                actions
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Virtual Date")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Virtual date").tweliEyebrow(.white.opacity(0.85))
            Text(current.title)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(current.date.formatted(date: .complete, time: .shortened))
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var notesCard: some View {
        CardView {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.quote").foregroundStyle(Color.twAccent2)
                Text(current.notes).font(.callout).foregroundStyle(.primary)
            }
        }
    }

    private var detailGrid: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                row("clock", "Status", current.status.label, tint: current.status.tint)
                Divider().padding(.leading, 48)
                row(current.reminderEnabled ? "bell.fill" : "bell.slash",
                    "Reminder", current.reminderEnabled ? "30 min before" : "Off",
                    tint: current.reminderEnabled ? .twAccent : .twInkTertiary)
                Divider().padding(.leading, 48)
                row("person", "Planned by", createdByLabel)
            }
        }
    }

    private func row(_ icon: String, _ label: String, _ value: String, tint: Color = .twAccent2) -> some View {
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
            if current.status == .planned {
                PrimaryButton(title: "Mark as Completed", systemImage: "checkmark") {
                    service.setStatus(current, .completed)
                }
                HStack(spacing: 10) {
                    PrimaryButton(title: current.reminderEnabled ? "Reminder on" : "Reminder off",
                                  systemImage: current.reminderEnabled ? "bell.fill" : "bell.slash",
                                  tint: .twAccent2, filled: false) {
                        toggleReminder()
                    }
                    PrimaryButton(title: "Cancel Date", systemImage: "xmark", tint: .twWarn, filled: false) {
                        service.setStatus(current, .cancelled)
                    }
                }
            } else {
                PrimaryButton(title: "Move back to Planned", systemImage: "arrow.uturn.left",
                              tint: .twAccent2, filled: false) {
                    service.setStatus(current, .planned)
                }
            }
            PrimaryButton(title: "Delete", systemImage: "trash", tint: .twWarn, filled: false) {
                service.delete(current)
                dismiss()
            }
        }
        .padding(.top, 4)
    }

    private func toggleReminder() {
        var updated = current
        updated.reminderEnabled.toggle()
        service.update(updated)
    }
}
