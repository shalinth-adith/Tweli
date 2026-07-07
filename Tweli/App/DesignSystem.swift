//
//  DesignSystem.swift
//  Tweli
//
//  Central design tokens mapped from the Twinderly design comp.
//  Every color maps 1:1 onto Apple's semantic system colors, so the whole
//  app adapts to light / dark automatically ("pure black dark, pure white light").
//

import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    /// Primary accent — iOS system pink (#FF2D55 light / #FF375F dark).
    static let twAccent = Color(UIColor.systemPink)
    /// Secondary accent — iOS system indigo (#5856D6 light / #5E5CE6 dark).
    static let twAccent2 = Color(UIColor.systemIndigo)

    static let twSuccess = Color(UIColor.systemGreen)
    static let twWarn = Color(UIColor.systemOrange)

    /// Screen background (--bg).
    static let twBackground = Color(UIColor.systemBackground)
    /// Elevated card background (--bg-elevated).
    static let twElevated = Color(UIColor.secondarySystemBackground)
    /// Second-level elevated background (--bg-elevated-2).
    static let twElevated2 = Color(UIColor.tertiarySystemBackground)

    /// Primary text (--ink). Use `.primary` directly where possible.
    static let twInk = Color(UIColor.label)
    static let twInkSecondary = Color(UIColor.secondaryLabel)
    static let twInkTertiary = Color(UIColor.tertiaryLabel)

    static let twSeparator = Color(UIColor.separator)

    /// Soft accent fill used behind pings / quick actions.
    static let twAccentSoft = Color(UIColor.systemPink).opacity(0.14)
    static let twAccent2Soft = Color(UIColor.systemIndigo).opacity(0.14)
}

// MARK: - Gradients

enum TweliGradient {
    /// The signature pink → indigo hero gradient (design 1b hero + large widget).
    static let hero = LinearGradient(
        colors: [.twAccent, .twAccent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Lock-screen / StandBy style deep gradient.
    static let dusk = LinearGradient(
        colors: [
            Color(red: 0.14, green: 0.10, blue: 0.18),
            Color(red: 0.36, green: 0.18, blue: 0.31),
            Color(red: 0.63, green: 0.29, blue: 0.36)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Metrics

enum TweliMetrics {
    static let cardRadius: CGFloat = 22
    static let heroRadius: CGFloat = 28
    static let chipRadius: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 14
}

// MARK: - Card modifier

private struct TweliCardModifier: ViewModifier {
    var radius: CGFloat = TweliMetrics.cardRadius
    var background: Color = .twElevated

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

extension View {
    /// Applies the standard elevated card look (rounded corners + soft shadow).
    func tweliCard(radius: CGFloat = TweliMetrics.cardRadius,
                   background: Color = .twElevated) -> some View {
        modifier(TweliCardModifier(radius: radius, background: background))
    }

    /// Small helper for the uppercase eyebrow labels used throughout the design.
    func tweliEyebrow(_ color: Color = .twInkTertiary) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}
