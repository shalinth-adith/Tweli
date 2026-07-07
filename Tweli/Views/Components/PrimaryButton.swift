//
//  PrimaryButton.swift
//  Tweli
//

import SwiftUI

/// Full-width filled button in the accent color (design's "Send love" / "Save").
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .twAccent
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(filled ? .white : tint)
            .background(filled ? tint : Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(filled ? Color.clear : Color.twSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Send love", systemImage: "heart.fill") {}
        PrimaryButton(title: "Plan a date", systemImage: "calendar", filled: false) {}
    }
    .padding()
}
