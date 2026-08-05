//
//  SplashView.swift
//  Tweli
//
//  Comp T1 (dark) / T1L (lite) — "Splash, T1 locked as canon". The thread and
//  nothing else: two lit endpoints, the curve drawing itself between them, then
//  the wordmark and the tagline arriving in that order.
//
//  Timing is taken from the comp's keyframes, which run on a 7s loop:
//
//      thread   draws  4% → 32%   (0.28s → 2.24s)
//      wordmark rises 20% → 32%   (1.40s → 2.24s)
//      tagline  rises 30% → 42%   (2.10s → 2.94s)
//
//  Two departures, both requested:
//
//  1. The comp's three loader dots at the bottom are gone. They were a
//     progress affordance for a splash that loops forever on a design canvas;
//     here the thread finishing IS the progress.
//  2. The splash no longer fades itself out. Fading its own sky to zero dipped
//     the screen through empty background before Home arrived — a visible dim
//     mid-transition. It now hands off at full opacity and the root cross-fades
//     straight from splash to app, so nothing darkens on the way.
//
//  `onFinished` still fires only after the sequence has played in full, so the
//  app never appears mid-animation.
//

import SwiftUI
import UIKit

struct SplashView: View {
    /// Called once the whole sequence has played and rested.
    var onFinished: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    @State private var threadDrawn = false
    @State private var wordIn = false
    @State private var tagIn = false

    // Comp keyframe times, in seconds on the 7s cycle.
    private let threadStart = 0.28, threadEnd = 2.24
    private let wordStart = 1.40
    private let tagStart = 2.10, tagEnd = 2.94
    /// How long the finished composition rests before handing over.
    private let hold = 0.55

    private var p: SplashPalette { scheme == .dark ? .dark : .light }

    var body: some View {
        ZStack {
            LinearGradient(colors: p.sky, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            twinkles

            VStack(spacing: 0) {
                thread
                    .frame(width: 240, height: 130)

                Text("Tweli")
                    .font(.system(size: 25, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(11)
                    // Tracking adds trailing space after the last glyph; pull it
                    // back so the word stays optically centred.
                    .padding(.leading, 11)
                    .foregroundStyle(p.word)
                    .padding(.top, 30)
                    .opacity(wordIn ? 1 : 0)
                    .offset(y: wordIn ? 0 : 14)

                Text("Closer every day")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(3.5)
                    .padding(.leading, 3.5)
                    .foregroundStyle(p.tagline)
                    .padding(.top, 13)
                    .opacity(tagIn ? 1 : 0)
                    .offset(y: tagIn ? 0 : 12)
            }
        }
        .task { await run() }
    }

    // MARK: - Timeline

    /// Drives the comp's sequence once, then reports completion. Written as a
    /// single async run rather than five scattered `.delay()` modifiers so the
    /// order is readable and the finish is guaranteed to come last.
    private func run() async {
        func wait(_ seconds: Double) async {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }

        await wait(threadStart)
        withAnimation(.easeInOut(duration: threadEnd - threadStart)) { threadDrawn = true }

        await wait(wordStart - threadStart)
        withAnimation(.easeOut(duration: threadEnd - wordStart)) { wordIn = true }

        await wait(tagStart - wordStart)
        withAnimation(.easeOut(duration: tagEnd - tagStart)) { tagIn = true }

        // Rest on the finished composition, then hand over at full opacity —
        // the root cross-fades, so there is no dip through an empty screen.
        await wait((tagEnd - tagStart) + hold)
        onFinished()
    }

    // MARK: - The thread

    private var thread: some View {
        ZStack {
            ThreadCurve()
                .trim(from: 0, to: threadDrawn ? 1 : 0)
                .stroke(
                    LinearGradient(colors: [p.dotStart, p.dotEnd],
                                   startPoint: .bottomLeading, endPoint: .topTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .shadow(color: p.threadGlow, radius: 4)

            // The two ends, at the curve's own endpoints in its 240×130 space.
            PulsingDot(size: 13, color: p.dotStart, glow: p.startGlow, radius: 7, delay: 0)
                .position(x: 30, y: 102)
            PulsingDot(size: 13, color: p.dotEnd, glow: p.endGlow, radius: 7, delay: 1.3)
                .position(x: 210, y: 28)
        }
    }

    // MARK: - Twinkles

    private var twinkles: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Twinkle(color: p.dotStart, size: p.twinkleSize, period: 4.0, delay: 0.5)
                    .position(x: w * 0.18, y: h * 0.20)
                Twinkle(color: p.dotEnd, size: p.twinkleSize, period: 4.6, delay: 1.7)
                    .position(x: w * 0.85, y: h * 0.31)
                Twinkle(color: p.thirdTwinkle, size: p.twinkleSize, period: 5.0, delay: 2.6)
                    .position(x: w * 0.26, y: h * 0.74)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Shape and motes

/// The comp's curve: `M30 102 C 90 22, 155 112, 210 28`, authored in a 240×130
/// box and scaled to whatever frame it's given.
private struct ThreadCurve: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 240, sy = rect.height / 130
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var p = Path()
        p.move(to: pt(30, 102))
        p.addCurve(to: pt(210, 28), control1: pt(90, 22), control2: pt(155, 112))
        return p
    }
}

/// Comp `tw-pulse`: scale 1 → 1.08, opacity 1 → 0.85, over 2.6s.
private struct PulsingDot: View {
    let size: CGFloat
    let color: Color
    let glow: Color
    let radius: CGFloat
    let delay: Double

    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glow, radius: radius)
            .scaleEffect(on ? 1.08 : 1)
            .opacity(on ? 0.85 : 1)
            .onAppear {
                // Half-period, because autoreverse supplies the return trip.
                withAnimation(.easeInOut(duration: 1.3)
                    .repeatForever(autoreverses: true)
                    .delay(delay)) { on = true }
            }
    }
}

/// Comp `tw-twinkle`: opacity 0.18 → 1, scale 0.75 → 1.2.
private struct Twinkle: View {
    let color: Color
    let size: CGFloat
    let period: Double
    let delay: Double

    @State private var lit = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(lit ? 1 : 0.18)
            .scaleEffect(lit ? 1.2 : 0.75)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2)
                    .repeatForever(autoreverses: true)
                    .delay(delay)) { lit = true }
            }
    }
}

// MARK: - Palette

/// T1 and T1L differ in more than the backdrop: the thread's gradient shifts (the
/// lite version uses the deeper #5E5CE6 → #FF375F so it reads on paper), the
/// endpoint glows soften, and the third twinkle turns amber instead of white.
private struct SplashPalette {
    let sky: [Color]
    let dotStart: Color
    let dotEnd: Color
    let startGlow: Color
    let endGlow: Color
    let threadGlow: Color
    let word: Color
    let tagline: Color
    let thirdTwinkle: Color
    let twinkleSize: CGFloat

    static let dark = SplashPalette(
        sky: [c(0x131022), c(0x0B0912), c(0x120A10)],
        dotStart: c(0x7B79FF),
        dotEnd: c(0xFF5E7E),
        startGlow: c(0x7B79FF).opacity(0.8),
        endGlow: c(0xFF5E7E).opacity(0.8),
        threadGlow: c(0xFF375F).opacity(0.4),
        word: .white,
        tagline: Color(UIColor.twLabel(0.45)),
        thirdTwinkle: .white,
        twinkleSize: 3
    )

    static let light = SplashPalette(
        sky: [c(0xF0EEFC), c(0xFDF5F7), c(0xFFF4EC)],
        dotStart: c(0x5E5CE6),
        dotEnd: c(0xFF375F),
        startGlow: c(0x5E5CE6).opacity(0.5),
        endGlow: c(0xFF375F).opacity(0.5),
        threadGlow: c(0xFF375F).opacity(0.25),
        word: c(0x1C1C1E),
        tagline: c(0x8E8E93),
        thirdTwinkle: c(0xFF9F0A),
        twinkleSize: 4
    )

    private static func c(_ hex: UInt32) -> Color { Color(UIColor.tw(hex)) }
}

#Preview { SplashView() }
