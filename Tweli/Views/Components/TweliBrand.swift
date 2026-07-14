//
//  TweliBrand.swift
//  Tweli
//
//  Shared brand motifs from the "Tweli Final" design (frames 19a–19h): the
//  signature gradient backdrop with drifting twinkles, the two-dots-one-thread
//  logo, the initial avatar bubble, and the gradient call-to-action button.
//  Centralised here so sign-in, create-space, invite and joining screens all
//  share one exact look and adapt to light / dark.
//

import SwiftUI

// MARK: - Hex color

extension Color {
    /// Builds a color from a 6-digit hex string (e.g. "5E5CE6"). Invalid input
    /// falls back to clear so a typo never crashes a release build.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&v), s.count == 6 else {
            self = .clear; return
        }
        self = Color(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

// MARK: - Brand palette (exact design values)

enum Brand {
    static let indigo = Color(hex: "5E5CE6")
    static let indigoLift = Color(hex: "7B79FF")
    static let pink = Color(hex: "FF2D55")
    static let pinkLift = Color(hex: "FF5E7E")
    static let green = Color(hex: "34C759")

    /// The pink→indigo CTA gradient, lifted slightly in dark mode to glow on ink.
    static func cta(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark ? [indigoLift, pinkLift] : [indigo, pink],
            startPoint: .leading, endPoint: .trailing
        )
    }

    /// Avatar gradients — "you" reads indigo, "partner" reads pink.
    static func youGradient() -> LinearGradient {
        LinearGradient(colors: [indigoLift, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func partnerGradient() -> LinearGradient {
        LinearGradient(colors: [pinkLift, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Gradient backdrop + twinkles

/// The full-screen brand backdrop used on sign-in and joining: a soft vertical
/// gradient with a few slowly-twinkling accent dots. Purely decorative.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var scheme
    var animateTwinkles = true

    private var stops: [Color] {
        scheme == .dark
            ? [Color(hex: "16112A"), Color(hex: "0D0A16"), Color(hex: "160B12")]
            : [Color(hex: "FFFFFF"), Color(hex: "F4F3FF"), Color(hex: "FFEFF2")]
    }

    var body: some View {
        LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
            .overlay(GeometryReader { geo in
                ZStack {
                    twinkle(0.17, 0.15, scheme == .dark ? Brand.indigoLift : Brand.indigo, 5, 0, geo.size)
                    twinkle(0.85, 0.25, scheme == .dark ? Brand.pinkLift : Brand.pink, 4, 0.6, geo.size)
                    twinkle(0.14, 0.44, scheme == .dark ? Brand.pinkLift : Brand.pink, 4, 1.1, geo.size)
                    twinkle(0.80, 0.70, scheme == .dark ? Brand.indigoLift : Brand.indigo, 4, 1.6, geo.size)
                }
            })
            .ignoresSafeArea()
    }

    private func twinkle(_ x: CGFloat, _ y: CGFloat, _ color: Color, _ size: CGFloat, _ delay: Double, _ bounds: CGSize) -> some View {
        TwinkleDot(color: color, size: size, delay: delay, animate: animateTwinkles)
            .position(x: bounds.width * x, y: bounds.height * y)
    }
}

private struct TwinkleDot: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    let animate: Bool
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 0.32 : 0.08)
            .onAppear {
                guard animate else { return }
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}

// MARK: - Thread logo (two dots, one thread)

/// The brand mark: an indigo dot and a pink dot joined by a drawn thread. The
/// thread strokes in on appear, the pink dot pops — matching the sign-in comp.
struct ThreadLogo: View {
    var size: CGFloat = 52
    @State private var draw = false
    @State private var pop = false

    var body: some View {
        Canvas { _, _ in } // sizing anchor
            .frame(width: size, height: size)
            .overlay(
                ZStack {
                    ThreadPath()
                        .trim(from: 0, to: draw ? 1 : 0)
                        .stroke(
                            LinearGradient(colors: [Brand.indigo, Brand.pink],
                                           startPoint: .bottomLeading, endPoint: .topTrailing),
                            style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                        )
                    dot(color: Brand.indigo).position(x: size * 0.2, y: size * 0.78)
                    dot(color: Brand.pink)
                        .scaleEffect(pop ? 1 : 0.2)
                        .position(x: size * 0.8, y: size * 0.22)
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).delay(0.3)) { draw = true }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(1.1)) { pop = true }
            }
    }

    private func dot(color: Color) -> some View {
        Circle().fill(color).frame(width: size * 0.22, height: size * 0.22)
    }
}

/// The shared thread curve, normalised to a unit-ish box scaled by the frame.
private struct ThreadPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.2, y: h * 0.78))
        p.addCurve(to: CGPoint(x: w * 0.8, y: h * 0.22),
                   control1: CGPoint(x: w * 0.4, y: h * 0.32),
                   control2: CGPoint(x: w * 0.6, y: h * 0.66))
        return p
    }
}

// MARK: - Avatar bubble

/// A round avatar showing a single initial on a brand gradient. `isPartner`
/// flips it to the pink gradient.
struct AvatarBubble: View {
    let initial: String
    var isPartner = false
    var size: CGFloat = 66

    var body: some View {
        Circle()
            .fill(isPartner ? Brand.partnerGradient() : Brand.youGradient())
            .frame(width: size, height: size)
            .overlay(
                Text(initial.isEmpty ? "·" : initial.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: (isPartner ? Brand.pink : Brand.indigo).opacity(0.32), radius: 12, y: 6)
    }
}

// MARK: - Gradient CTA button

/// The primary gradient call-to-action (pink→indigo) used across the pairing
/// flow. Shows a trailing arrow, or a spinner + custom label while `loading`.
struct BrandCTA: View {
    let title: String
    var loading = false
    var showsArrow = true
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if loading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                if showsArrow && !loading {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Brand.cta(scheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Brand.pink.opacity(scheme == .dark ? 0.35 : 0.3), radius: 16, y: 10)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Subtle press-scale used on brand buttons for a tactile, production feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
