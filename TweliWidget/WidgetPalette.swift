//
//  WidgetPalette.swift
//  TweliWidget
//
//  The widget extension is a separate target and cannot see the app's
//  DesignSystem.swift, so the handful of tokens the widget needs are mirrored
//  here. Same rule as the app: light values come from the comp's L screens
//  (C1 / L10), dark values from the N screens (N10). Keep the two in step.
//

import SwiftUI
import UIKit

enum WidgetPalette {

    private static func hex(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red:   CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >>  8) & 0xFF) / 255,
                blue:  CGFloat( v        & 0xFF) / 255,
                alpha: a)
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Your dot — the near end of the thread.
    static let me = dynamic(light: hex(0xFF2D55), dark: hex(0xFF375F))
    /// Your partner's dot — the far end.
    static let partner = dynamic(light: hex(0x5E5CE6), dark: hex(0x5E5CE6))
    /// The travelled part of the thread, and the heart riding it.
    static let thread = dynamic(light: hex(0xFF2D55), dark: hex(0xFF5E7E))
    /// The untravelled remainder.
    static let threadTrack = dynamic(light: hex(0xFF2D55, 0.2), dark: hex(0xFF5E7E, 0.25))

    static let ink = dynamic(light: hex(0x1C1C1E), dark: hex(0xFFFFFF))
    static let inkSecondary = dynamic(light: hex(0x6D6D72),
                                      dark: UIColor(red: 235/255, green: 235/255, blue: 245/255, alpha: 0.5))
    static let inkTertiary = dynamic(light: hex(0xAEAEB2),
                                     dark: UIColor(red: 235/255, green: 235/255, blue: 245/255, alpha: 0.35))

    /// The "21 days" pill that rides the thread on the medium widget.
    static let pillFill = dynamic(light: hex(0xFFFFFF), dark: hex(0x2C2C2E))
    /// "Send love".
    static let actionFill = dynamic(light: hex(0xFF2D55, 0.1), dark: hex(0xFF375F, 0.16))
    static let actionInk = dynamic(light: hex(0xFF2D55), dark: hex(0xFF5E7E))
}
