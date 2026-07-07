//
//  ReminderRowView.swift
//  Tweli
//

import SwiftUI

struct ReminderRowView: View {
    let reminder: ReminderItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isCompleted ? Color.twSuccess : Color.twInkTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .tertiary : .primary)

                if !reminder.note.isEmpty {
                    Text(reminder.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    ChipView.assignee(reminder.assignedTo)
                    if reminder.isRepeating {
                        ChipView(text: reminder.repeatType.label, systemImage: "repeat", tint: .twInkSecondary)
                    }
                    if reminder.priority == .important {
                        ChipView(text: "Important", systemImage: "exclamationmark", tint: .twWarn)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(reminder.timeLabel)
                    .font(.caption).foregroundStyle(.tertiary)
                if reminder.isMissed {
                    Text("Missed").font(.caption2.weight(.semibold)).foregroundStyle(Color.twWarn)
                }
            }
        }
        .padding(14)
        .tweliCard()
    }
}
