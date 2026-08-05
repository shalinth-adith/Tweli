//
//  ReminderRowView.swift
//  Tweli
//
//  One reminder row inside a group card (comp L8 / N8 / B6). The row itself has
//  no card chrome — the enclosing group draws that — so it is just: checkbox,
//  title + meta, and the owner's avatar dot.
//
//  Comp geometry: 23pt checkbox at radius 7, title 15/700 (15/600 struck and
//  tertiary once done), meta 12, owner dot 22pt.
//

import SwiftUI

struct ReminderRowView: View {
    let reminder: ReminderItem
    /// True for the single "next up" reminder, which the comp gives a glowing
    /// accent-outlined checkbox — the only lit thing in the list.
    var isNext = false
    /// Initials of whoever the reminder belongs to, for the trailing dot.
    var ownerInitials: String = ""
    /// Whether that owner is the partner (indigo dot) rather than you (pink).
    var ownerIsPartner = false
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            checkbox
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 15, weight: reminder.isCompleted ? .semibold : .bold))
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? Color.twInkTertiary : Color.twInk)
                    .lineLimit(2)
                Text(metaLine)
                    .font(.system(size: 12))
                    .foregroundStyle(reminder.isCompleted ? Color.twInkQuaternary : Color.twInkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !ownerInitials.isEmpty { ownerDot }
        }
        .padding(.vertical, isNext ? 14 : 12)
    }

    // MARK: - Checkbox

    private var checkbox: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(reminder.isCompleted ? Color.twAccent : .clear)
                )
                .frame(width: 23, height: 23)
                .overlay {
                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                // Comp: the next-up checkbox carries 0 0 10px rgba(255,55,95,0.35).
                .shadow(color: isNext && !reminder.isCompleted ? Color.twAccent.opacity(0.35) : .clear,
                        radius: 5)
        }
        .buttonStyle(.plain)
    }

    private var strokeColor: Color {
        if reminder.isCompleted { return .clear }
        if isNext { return .twAccentLight }
        return reminder.isMissed ? .twWarn : .twControlStroke
    }

    // MARK: - Owner dot

    private var ownerDot: some View {
        Circle()
            .fill(ownerIsPartner ? TweliGradient.partnerAvatar : TweliGradient.meAvatar)
            .frame(width: 22, height: 22)
            .overlay {
                Text(ownerInitials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Meta

    /// Comp: "6:30 PM · her 5:00 PM", "9:00 AM · you asked her". We show the time
    /// plus whichever qualifier we actually know, never a fabricated one.
    private var metaLine: String {
        var parts = [reminder.timeLabel]
        if reminder.isRepeating { parts.append(reminder.repeatType.label) }
        if !reminder.note.isEmpty { parts.append(reminder.note) }
        if reminder.isMissed && !reminder.isCompleted { parts.append("missed") }
        return parts.joined(separator: " · ")
    }
}
