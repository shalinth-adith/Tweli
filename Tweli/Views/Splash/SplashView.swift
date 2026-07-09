//
//  SplashView.swift
//  Tweli
//
//  Design 17a (light) / 17b (dark) — the animated entry screen. The story plays
//  in order: your dot lands → the thread draws across → your partner's dot pops
//  as it arrives → "Tweli · Closer every day" settles → the tile breathes.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var scheme

    @State private var dot1 = false        // your dot (bottom-left)
    @State private var thread: CGFloat = 0 // thread draw progress
    @State private var dot2 = false        // partner's dot (top-right)
    @State private var tileIn = false
    @State private var word = false
    @State private var subtitle = false
    @State private var dotsIn = false
    @State private var breathe = false
    @State private var glow = false

    private var p: SplashPalette { scheme == .dark ? .dark : .light }

    var body: some View {
        ZStack {
            LinearGradient(colors: p.bg, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            twinkles

            VStack(spacing: 30) {
                iconTile
                wordmark
            }
        }
        .overlay(alignment: .bottom) { loadingDots.padding(.bottom, 64) }
        .onAppear(perform: runIntro)
    }

    // MARK: - Icon tile (glow + breathing tile + thread motif)

    private var iconTile: some View {
        ZStack {
            Circle()
                .fill(p.glow)
                .frame(width: 150, height: 150)
                .scaleEffect(glow ? 1.08 : 0.9)
                .opacity(glow ? 0.9 : 0.45)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: p.tile, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 116, height: 116)
                .shadow(color: p.tileShadow, radius: 22, x: 0, y: 14)
                .overlay(threadMotif)
                .scaleEffect(tileIn ? 1 : 0.7)
                .scaleEffect(breathe ? 1.025 : 0.99)
                .opacity(tileIn ? 1 : 0)
        }
    }

    private var threadMotif: some View {
        ZStack {
            ThreadShape()
                .trim(from: 0, to: thread)
                .stroke(LinearGradient(colors: [p.dot1, p.dot2],
                                       startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))

            dot(color: p.dot1, at: CGPoint(x: 5.0 / 24, y: 18.0 / 24), shown: dot1)
            dot(color: p.dot2, at: CGPoint(x: 19.0 / 24, y: 6.0 / 24), shown: dot2)
        }
        .frame(width: 68, height: 68)
    }

    private func dot(color: Color, at unit: CGPoint, shown: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 15, height: 15)
            .scaleEffect(shown ? 1 : 0)
            .position(x: unit.x * 68, y: unit.y * 68)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        VStack(spacing: 9) {
            Text("TWELI")
                .font(.system(size: 25, weight: .semibold))
                .tracking(9)
                .foregroundStyle(p.word)
                .opacity(word ? 1 : 0)
                .offset(y: word ? 0 : 12)
            Text("CLOSER EVERY DAY")
                .font(.system(size: 11.5, weight: .medium))
                .tracking(2.6)
                .foregroundStyle(p.subtitle)
                .opacity(subtitle ? 1 : 0)
                .offset(y: subtitle ? 0 : 10)
        }
    }

    // MARK: - Loading dots

    private var loadingDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(p.loading[i])
                    .frame(width: 6, height: 6)
                    .opacity(dotsIn ? (breathe ? 1 : 0.4) : 0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.2), value: breathe)
            }
        }
        .opacity(dotsIn ? 1 : 0)
    }

    // MARK: - Ambient twinkles

    private var twinkles: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                twinkle(p.dot1, x: 0.20 * w, y: 0.22 * h, delay: 0.0)
                twinkle(p.dot2, x: 0.83 * w, y: 0.31 * h, delay: 0.6)
                twinkle(p.dot2, x: 0.26 * w, y: 0.70 * h, delay: 1.1)
                twinkle(p.dot1, x: 0.76 * w, y: 0.64 * h, delay: 0.4)
            }
        }
        .ignoresSafeArea()
    }

    private func twinkle(_ color: Color, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .opacity(glow ? (scheme == .dark ? 0.35 : 0.22) : 0.08)
            .scaleEffect(glow ? 1.2 : 0.7)
            .position(x: x, y: y)
            .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true).delay(delay), value: glow)
    }

    // MARK: - Choreography

    private func runIntro() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { tileIn = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.35)) { dot1 = true }
        withAnimation(.easeInOut(duration: 1.2).delay(0.55)) { thread = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(1.55)) { dot2 = true }
        withAnimation(.easeOut(duration: 0.8).delay(1.75)) { word = true }
        withAnimation(.easeOut(duration: 0.8).delay(2.05)) { subtitle = true }
        withAnimation(.easeOut(duration: 0.6).delay(2.4)) { dotsIn = true }
        withAnimation(.easeInOut(duration: 4.5).delay(2.4).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 2.8).delay(2.2).repeatForever(autoreverses: true)) { glow = true }
    }
}

/// The two-dots-and-thread motif path, drawn in a 24×24 space and scaled to fit.
private struct ThreadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var path = Path()
        path.move(to: CGPoint(x: 5 * s, y: 18 * s))
        path.addCurve(to: CGPoint(x: 19 * s, y: 6 * s),
                      control1: CGPoint(x: 9.5 * s, y: 8.5 * s),
                      control2: CGPoint(x: 14.5 * s, y: 15.5 * s))
        return path
    }
}

private func splashRGB(_ hex: UInt) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255,
          green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255)
}

private struct SplashPalette {
    let bg: [Color]
    let tile: [Color]
    let tileShadow: Color
    let glow: Color
    let dot1: Color
    let dot2: Color
    let word: Color
    let subtitle: Color
    let loading: [Color]

    static let light = SplashPalette(
        bg: [splashRGB(0xFFFFFF), splashRGB(0xF4F3FF), splashRGB(0xFFEFF2)],
        tile: [splashRGB(0xFFFFFF), splashRGB(0xF1F0FF)],
        tileShadow: splashRGB(0x5E5CE6).opacity(0.18),
        glow: splashRGB(0x5E5CE6).opacity(0.16),
        dot1: splashRGB(0x5E5CE6), dot2: splashRGB(0xFF2D55),
        word: splashRGB(0x1C1C1E), subtitle: splashRGB(0x8E8E93),
        loading: [splashRGB(0x5E5CE6), splashRGB(0xB58AE6), splashRGB(0xFF2D55)]
    )

    static let dark = SplashPalette(
        bg: [splashRGB(0x16112A), splashRGB(0x0D0A16), splashRGB(0x160B12)],
        tile: [splashRGB(0x1E1830), splashRGB(0x0D0A16)],
        tileShadow: splashRGB(0x5E5CE6).opacity(0.4),
        glow: splashRGB(0x7B79FF).opacity(0.22),
        dot1: splashRGB(0x7B79FF), dot2: splashRGB(0xFF5E7E),
        word: .white, subtitle: splashRGB(0x98989F),
        loading: [splashRGB(0x7B79FF), splashRGB(0xB58AE6), splashRGB(0xFF5E7E)]
    )
}

#Preview { SplashView() }
