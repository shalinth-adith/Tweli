//
//  DesignSystem.swift
//  Tweli
//
//  Central design tokens, taken literally from the "Twinderly A–Z" comp.
//
//  The comp specifies two complete palettes and they are NOT Apple's semantic
//  colors — light backgrounds are #F7F6FA (not white), dark is true #000 with
//  #1C1C1E cards, and the accents *shift* between modes. So every token here is
//  defined twice:
//
//      TwPalette.light  ← screens L1–L14
//      TwPalette.dark   ← screens N1–N14
//
//  `Color.twX` resolves between them through a dynamic UIColor, so a call site
//  never has to know which mode it is in — and an explicit theme override
//  (Our space → Theme → Light/Dark) propagates through the trait collection and
//  is respected automatically. See ThemeService.
//

import SwiftUI
import UIKit

// MARK: - Palette

/// One complete set of design tokens. Two instances exist: `.light` (comp
/// screens L1–L14) and `.dark` (comp screens N1–N14).
struct TwPalette {

    // Surfaces
    let background: UIColor          // screen behind everything
    let elevated: UIColor            // card
    let elevated2: UIColor           // card nested inside a card / grouped row
    let elevatedWarm: UIColor        // top stop of the "next up" group's warm wash
    let barBackground: UIColor       // floating tab bar + sticky headers

    // Ink
    let ink: UIColor                 // titles, values
    let inkSecondary: UIColor        // body copy, quoted message
    let inkTertiary: UIColor         // eyebrows, meta, inactive icons
    let inkQuaternary: UIColor       // completed rows, footnotes, disabled
    let inkChip: UIColor             // label on an unselected chip / segmented control

    // Accent — the pink thread
    let accent: UIColor              // fills, active tab, dots
    let accentInk: UIColor           // accent used as *text/icon* (needs contrast)
    let accentLight: UIColor         // gradient partner + glow strokes

    // Secondary accent — the indigo half of the thread
    let indigo: UIColor
    let indigoInk: UIColor           // indigo used as text (night banner copy)

    // Semantic
    let info: UIColor                // the "N km apart" distance band
    let warn: UIColor                // overdue / morning banner
    let warnInk: UIColor             // warn used as text
    let success: UIColor
    let danger: UIColor              // the single destructive action ("Leave this space")

    // Letter paper — the opened letter is warm stationery in BOTH modes
    // (comp L7 "warm paper", N7 "candlelit paper"), never a plain card.
    let paperTop: UIColor
    let paperBottom: UIColor
    let paperRing: UIColor
    let paperInk: UIColor
    let paperInkStrong: UIColor

    // Lines
    let separator: UIColor           // divider inside a card
    let hairline: UIColor            // card border / control outline
    let controlStroke: UIColor       // unchecked checkbox, empty ring

    // Elevation — expressed differently per mode, so the palette owns it.
    // Light draws a drop shadow; dark draws an inset hairline plus an outward
    // glow. One shadow modifier with a swapped color cannot express both.
    let usesInsetBorder: Bool
    let shadowColor: UIColor
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let glowColor: UIColor           // hero-card bloom (pink, very low alpha)
    let glowRadius: CGFloat
}

extension TwPalette {

    /// Light mode — comp screens L1–L14.
    static let light = TwPalette(
        background:     .tw(0xF7F6FA),
        elevated:       .tw(0xFFFFFF),
        elevated2:      .tw(0xF2F0FF),
        elevatedWarm:   .tw(0xFFF0F3),
        barBackground:  .tw(0xFFFFFF, 0.94),

        ink:            .tw(0x1C1C1E),
        inkSecondary:   .tw(0x6D6D72),
        inkTertiary:    .tw(0x8E8E93),
        inkQuaternary:  .tw(0xAEAEB2),
        inkChip:        .tw(0x3C3C43),

        accent:         .tw(0xFF375F),
        accentInk:      .tw(0xE8325A),
        accentLight:    .tw(0xFF5E7E),

        indigo:         .tw(0x5E5CE6),
        indigoInk:      .tw(0x5E5CE6),

        info:           .tw(0x0A84FF),
        warn:           .tw(0xFF9F0A),
        warnInk:        .tw(0xB96E00),
        success:        .tw(0x30D158),
        danger:         .tw(0xFF3B30),

        paperTop:       .tw(0xFFFCF4),
        paperBottom:    .tw(0xFBF2E2),
        paperRing:      UIColor(red: 214/255, green: 170/255, blue: 90/255, alpha: 0.35),
        paperInk:       .tw(0x4A3B28),
        paperInkStrong: .tw(0x5A4632),

        separator:      UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.10),
        hairline:       UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.12),
        controlStroke:  UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.28),

        usesInsetBorder: false,
        shadowColor:    .tw(0x000000, 0.06),
        shadowRadius:   10,
        shadowY:        3,
        glowColor:      .tw(0xFF375F, 0.10),
        glowRadius:     34
    )

    /// Dark mode — comp screens N1–N14. "Not an inversion — a mood."
    static let dark = TwPalette(
        background:     .tw(0x000000),
        elevated:       .tw(0x1C1C1E),
        elevated2:      .tw(0x16112A),
        elevatedWarm:   .tw(0x241A20),
        barBackground:  .tw(0x1C1C1E, 0.95),

        ink:            .tw(0xFFFFFF),
        inkSecondary:   .twLabel(0.55),
        inkTertiary:    .twLabel(0.40),
        inkQuaternary:  .twLabel(0.30),
        inkChip:        .twLabel(0.75),

        accent:         .tw(0xFF375F),
        accentInk:      .tw(0xFF5E7E),
        accentLight:    .tw(0xFF6B8A),

        indigo:         .tw(0x7B79FF),
        indigoInk:      .tw(0x9C9AFF),

        info:           .tw(0x5AB0FF),
        warn:           .tw(0xFF9F0A),
        warnInk:        .tw(0xFF9F0A),
        success:        .tw(0x30D158),
        danger:         .tw(0xFF453A),

        paperTop:       .tw(0x26201B),
        paperBottom:    .tw(0x1C1A18),
        paperRing:      UIColor(red: 255/255, green: 214/255, blue: 107/255, alpha: 0.14),
        paperInk:       .tw(0xEFE3D0),
        paperInkStrong: .tw(0xF5E9DA),

        separator:      .tw(0xFFFFFF, 0.08),
        hairline:       .tw(0xFFFFFF, 0.06),
        controlStroke:  .tw(0xFFFFFF, 0.22),

        usesInsetBorder: true,
        shadowColor:    .clear,
        shadowRadius:   0,
        shadowY:        0,
        glowColor:      .tw(0xFF375F, 0.08),
        glowRadius:     40
    )

    /// The palette for a given interface style. Everything funnels through here.
    static func resolved(for style: UIUserInterfaceStyle) -> TwPalette {
        style == .dark ? .dark : .light
    }
}

// MARK: - Hex helpers

extension UIColor {
    /// `.tw(0xFF375F)` — the comp writes colors as hex, so we do too.
    static func tw(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red:   CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >>  8) & 0xFF) / 255,
                blue:  CGFloat( hex        & 0xFF) / 255,
                alpha: alpha)
    }

    /// The comp's dark-mode ink ramp is all `rgba(235,235,245,α)`.
    static func twLabel(_ alpha: CGFloat) -> UIColor {
        UIColor(red: 235/255, green: 235/255, blue: 245/255, alpha: alpha)
    }

    /// Resolves light/dark from the two palettes at trait-collection time.
    static func twDynamic(_ token: KeyPath<TwPalette, UIColor>) -> UIColor {
        UIColor { trait in TwPalette.resolved(for: trait.userInterfaceStyle)[keyPath: token] }
    }
}

// MARK: - Colors

extension Color {
    /// Primary accent — the pink thread (#FF375F in both modes).
    static let twAccent      = Color(UIColor.twDynamic(\.accent))
    /// Accent as *text or icon* — L #E8325A / N #FF5E7E. Use this whenever the
    /// accent carries a glyph, not a fill; `twAccent` is too light to read on
    /// white and too dark to read on black.
    static let twAccentInk   = Color(UIColor.twDynamic(\.accentInk))
    /// The lighter pink used in gradients and glowing strokes.
    static let twAccentLight = Color(UIColor.twDynamic(\.accentLight))

    /// Secondary accent — the indigo half of the thread.
    static let twAccent2     = Color(UIColor.twDynamic(\.indigo))
    /// Indigo as text (the "she's asleep" night banner).
    static let twAccent2Ink  = Color(UIColor.twDynamic(\.indigoInk))

    static let twSuccess     = Color(UIColor.twDynamic(\.success))
    /// Destructive — comp L9/N9 "Leave this space" (#FF3B30 / #FF453A).
    static let twDanger      = Color(UIColor.twDynamic(\.danger))
    static let twWarn        = Color(UIColor.twDynamic(\.warn))
    static let twWarnInk     = Color(UIColor.twDynamic(\.warnInk))
    /// Informational blue — the "N km apart" distance band.
    static let twInfo        = Color(UIColor.twDynamic(\.info))

    /// Screen background — L #F7F6FA / N #000.
    static let twBackground  = Color(UIColor.twDynamic(\.background))
    /// Card background — L #FFFFFF / N #1C1C1E.
    static let twElevated    = Color(UIColor.twDynamic(\.elevated))
    static let twElevated2   = Color(UIColor.twDynamic(\.elevated2))
    /// Warm top stop of the "next up" group — L #FFF0F3 / N #241A20.
    static let twElevatedWarm = Color(UIColor.twDynamic(\.elevatedWarm))
    /// Floating bar / sticky header fill.
    static let twBar         = Color(UIColor.twDynamic(\.barBackground))

    static let twInk           = Color(UIColor.twDynamic(\.ink))
    static let twInkSecondary  = Color(UIColor.twDynamic(\.inkSecondary))
    static let twInkTertiary   = Color(UIColor.twDynamic(\.inkTertiary))
    static let twInkQuaternary = Color(UIColor.twDynamic(\.inkQuaternary))
    /// Label on an unselected chip — L #3C3C43 / N rgba(235,235,245,0.75).
    static let twInkChip       = Color(UIColor.twDynamic(\.inkChip))

    /// The opened letter's stationery — warm in both modes (comp L7 / N7).
    static let twPaperTop       = Color(UIColor.twDynamic(\.paperTop))
    static let twPaperBottom    = Color(UIColor.twDynamic(\.paperBottom))
    static let twPaperRing      = Color(UIColor.twDynamic(\.paperRing))
    static let twPaperInk       = Color(UIColor.twDynamic(\.paperInk))
    static let twPaperInkStrong = Color(UIColor.twDynamic(\.paperInkStrong))

    static let twSeparator     = Color(UIColor.twDynamic(\.separator))
    static let twHairline      = Color(UIColor.twDynamic(\.hairline))
    static let twControlStroke = Color(UIColor.twDynamic(\.controlStroke))

    /// Soft accent fills used behind pings / quick actions (comp: rgba(255,55,95,0.14)).
    static let twAccentSoft  = Color(UIColor.twDynamic(\.accent)).opacity(0.14)
    static let twAccent2Soft = Color(UIColor.twDynamic(\.indigo)).opacity(0.14)
}

// MARK: - Gradients

enum TweliGradient {
    /// Your own avatar — the pink dot at the near end of the thread.
    static let meAvatar = LinearGradient(
        colors: [Color(UIColor.tw(0xFF6B8A)), Color(UIColor.tw(0xFF375F))],
        startPoint: .top, endPoint: .bottom
    )

    /// Your partner's avatar — the indigo dot at the far end.
    static let partnerAvatar = LinearGradient(
        colors: [Color(UIColor.tw(0x8E8CFF)), Color(UIColor.tw(0x5E5CE6))],
        startPoint: .top, endPoint: .bottom
    )

    /// The thread itself: indigo → pink, the app's one signature.
    static let thread = LinearGradient(
        colors: [Color(UIColor.tw(0x7B79FF)), Color(UIColor.tw(0xFF5E7E))],
        startPoint: .leading, endPoint: .trailing
    )

    /// The signature pink → indigo hero gradient.
    static let hero = LinearGradient(
        colors: [.twAccent, .twAccent2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Splash / thread-ties sky. Dawn on light (L1), aurora on dark (N1).
    static func sky(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [Color(UIColor.tw(0x16112A)), Color(UIColor.tw(0x0D0A16)), Color(UIColor.tw(0x160B12))],
                             startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(UIColor.tw(0xF2F0FF)), Color(UIColor.tw(0xFFF6F8)), Color(UIColor.tw(0xFFF3ED))],
                             startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Metrics

enum TweliMetrics {
    /// The comp's card radii: 24 for the hero card, 20 for standard cards,
    /// 14 for inline bands, 13 for chips.
    static let heroRadius: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let bandRadius: CGFloat = 14
    static let chipRadius: CGFloat = 13
    static let screenPadding: CGFloat = 18
    static let cardSpacing: CGFloat = 12
}

// MARK: - Card modifier

/// Applies the comp's card treatment for the *current* mode. Light gets a drop
/// shadow; dark gets an inset hairline plus, on hero cards, a pink bloom.
private struct TweliCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    var radius: CGFloat
    var background: Color
    var hero: Bool

    private var palette: TwPalette { scheme == .dark ? .dark : .light }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(background)
            .clipShape(shape)
            .overlay {
                // Dark mode's card edge is an inset hairline, not a shadow.
                if palette.usesInsetBorder {
                    shape.strokeBorder(Color.twHairline, lineWidth: 0.5)
                }
            }
            .shadow(color: Color(palette.shadowColor),
                    radius: palette.shadowRadius, x: 0, y: palette.shadowY)
            // The hero (partner-mood) card blooms pink in both modes.
            .shadow(color: hero ? Color(palette.glowColor) : .clear,
                    radius: hero ? palette.glowRadius : 0,
                    x: 0, y: hero && !palette.usesInsetBorder ? 10 : 0)
    }
}

extension View {
    /// The standard elevated card look. Pass `hero: true` for the partner-mood
    /// card, which carries the pink bloom in both modes.
    func tweliCard(radius: CGFloat = TweliMetrics.cardRadius,
                   background: Color = .twElevated,
                   hero: Bool = false) -> some View {
        modifier(TweliCardModifier(radius: radius, background: background, hero: hero))
    }

    /// The uppercase eyebrow label used above every card section.
    /// Comp: 11px / 700 / uppercase / +0.5px tracking / inkTertiary.
    func tweliEyebrow(_ color: Color = .twInkTertiary) -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}
