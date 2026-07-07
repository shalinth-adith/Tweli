//
//  EmptyStateView.swift
//  Tweli
//

import SwiftUI

/// Warm empty-state used when a list has no content yet.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.twAccentSoft).frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.twAccent)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: "plus", action: action)
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}

#Preview {
    EmptyStateView(icon: "bell.badge",
                   title: "No reminders yet",
                   subtitle: "Add a small nudge for something important.",
                   actionTitle: "Add Reminder") {}
}
