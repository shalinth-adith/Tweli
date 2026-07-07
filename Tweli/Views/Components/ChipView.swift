//
//  ChipView.swift
//  Tweli
//

import SwiftUI

/// Small pill chip used for assignee / repeat / priority / status labels.
struct ChipView: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .twAccent2
    var soft: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage, !systemImage.isEmpty {
                Image(systemName: systemImage).font(.caption2.weight(.semibold))
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(soft ? tint : .white)
        .background(soft ? tint.opacity(0.15) : tint)
        .clipShape(Capsule())
    }
}

extension ChipView {
    /// Convenience for a reminder's assignee chip.
    static func assignee(_ a: ReminderAssignee) -> ChipView {
        ChipView(text: a.label, systemImage: a.sfSymbol, tint: a == .partner ? .twAccent : .twAccent2)
    }
}

#Preview {
    HStack {
        ChipView.assignee(.both)
        ChipView(text: "Daily", systemImage: "repeat")
        ChipView(text: "Important", tint: .twWarn)
    }
    .padding()
}
