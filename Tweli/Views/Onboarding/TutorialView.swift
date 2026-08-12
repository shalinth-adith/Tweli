//
//  TutorialView.swift
//  Tweli
//
//  Comp 0Z — the entry tutorial. Three animated pages shown once, after the
//  splash and BEFORE sign-in, skippable at any point:
//
//    Z1  The thread   — the line draws itself between your two dots
//    Z2  Moods        — the widget floats, the mood pulses onto it
//    Z3  Letters      — a sealed letter waits until the right night
//
//  Placing it ahead of Sign in with Apple is the point, not an accident: it is
//  the only chance to say what Tweli is before asking for an identity. That
//  matters most for the invited partner, who did not go looking for this app.
//
//  The comp is drawn on the dark palette (#16112A → #0D0A16 → #160B12), which
//  is exactly `TweliGradient.sky(.dark)`. Using the token instead of the literal
//  hexes keeps the page faithful in dark and coherent in light, matching
//  SignInView — the screen this one hands off to.
//

import SwiftUI

struct TutorialView: View {

    /// Called on Skip and on "Start your thread" alike — both mean "done".
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private static let pageCount = 3

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            // Comp: two drifting specks on Z1, one on Z3, none on Z2.
            if page == 0 {
                TwinkleDot(delay: 0.7, period: 4.2, color: Brand.indigoLift)
                    .position(x: 62, y: 130)
                TwinkleDot(delay: 1.6, period: 4.7, color: Brand.pinkLift)
                    .position(x: 320, y: 180)
            } else if page == 2 {
                TwinkleDot(delay: 0.9, period: 4.4, color: Brand.pinkLift)
                    .position(x: 78, y: 158)
            }

            VStack(spacing: 0) {
                skipRow

                // Chrome (dots + CTA) is hoisted out of the pager so it stays
                // put while pages move. The comp draws it on every page in the
                // same position, so this is faithful and avoids three copies.
                TabView(selection: $page) {
                    threadPage.tag(0)
                    moodPage.tag(1)
                    letterPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots.padding(.top, 26)   // comp: margin-top 30 under the body copy

                BrandCTA(title: page == Self.pageCount - 1 ? "Start your thread" : "Next",
                         showsArrow: false) {
                    advance()
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: page)
#if DEBUG
        .onAppear {
            // Verification hook (DEBUG only, same shape as TWELI_TAB):
            // TWELI_TUTORIAL_PAGE=<0-2> opens straight to a page, because
            // simulators cannot inject the swipe or the Next tap.
            if let raw = ProcessInfo.processInfo.environment["TWELI_TUTORIAL_PAGE"],
               let p = Int(raw), (0..<Self.pageCount).contains(p) {
                page = p
            }
        }
#endif
    }

    private func advance() {
        if page < Self.pageCount - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }

    // MARK: - Chrome

    private var skipRow: some View {
        HStack {
            Spacer()
            Button("Skip") { onFinish() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.twInkTertiary)
                .accessibilityHint("Skips the introduction and goes to sign in")
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<Self.pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Brand.pinkLift : Color.twInk.opacity(0.2))
                    .frame(width: i == page ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
        .accessibilityHidden(true)
    }

    /// Title + body, identical across the three pages.
    private func copyBlock(_ title: String, _ body: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text(body)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
    }

    private func page(art: some View, title: String, body: String) -> some View {
        // Comp: the art sits in a `flex:1` box that absorbs all the slack and
        // centres its contents, with the copy packed directly beneath it. Using
        // separate spacers above and below the art instead would split the slack
        // evenly and open a gap between the picture and the sentence explaining
        // it — the two need to read as one unit.
        VStack(spacing: 22) {
            art.frame(maxHeight: .infinity)
            copyBlock(title, body)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Z1 · The thread

    private var threadPage: some View {
        page(art: ThreadArt(animated: !reduceMotion),
             title: "One thread,\ntwo of you.",
             body: "Tweli is a private line between your phone and theirs. Nothing here is ever public.")
    }

    // MARK: - Z2 · Moods on the widget

    private var moodPage: some View {
        page(art: FloatingArt(period: 4.5, animated: !reduceMotion) { MoodWidgetCard() },
             title: "Her mood lives\non your home screen.",
             body: "Set yours in two taps — it lands on their widget the same second, anywhere on earth.")
    }

    // MARK: - Z3 · Letters

    private var letterPage: some View {
        page(art: FloatingArt(period: 5, animated: !reduceMotion) { SealedLetterCard() },
             title: "Letters that wait\nfor the right night.",
             body: "Seal one for a birthday, a hard day, or \"open when you miss me.\" It stays locked until then.")
    }
}

// MARK: - Z1 art

/// The signature curve drawing itself between the pink dot (you) and the indigo
/// one (them). Comp geometry is a 280×150 SVG; kept in that coordinate space so
/// the control points can be read straight off the comp.
private struct ThreadArt: View {
    let animated: Bool

    @State private var progress: CGFloat = 0
    @State private var pulsing = false

    private static let size = CGSize(width: 280, height: 150)
    private static let start = CGPoint(x: 30, y: 106)
    private static let end   = CGPoint(x: 250, y: 44)

    private var threadPath: Path {
        var p = Path()
        p.move(to: Self.start)
        p.addCurve(to: Self.end,
                   control1: CGPoint(x: 100, y: 30),
                   control2: CGPoint(x: 180, y: 128))
        return p
    }

    var body: some View {
        ZStack {
            threadPath
                .trim(from: 0, to: progress)
                .stroke(TweliGradient.thread,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))

            dot(at: Self.start, core: Brand.pinkLift,
                halo: Color(UIColor.tw(0xFF5E7E, 0.16)), phase: 0)
            dot(at: Self.end, core: Color(UIColor.tw(0x8E8CFF)),
                halo: Color(UIColor.tw(0x8E8CFF, 0.16)), phase: 1.5)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear {
            guard animated else { progress = 1; return }
            // Comp: 2.6s ease, 0.5s in — the pause before it starts is what
            // makes the line read as being drawn rather than revealed.
            withAnimation(.easeInOut(duration: 2.6).delay(0.5)) { progress = 1 }
            pulsing = true
        }
        .accessibilityElement()
        .accessibilityLabel("A thread drawing itself between two dots")
    }

    private func dot(at p: CGPoint, core: Color, halo: Color, phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(halo)
                .frame(width: 32, height: 32)
                .scaleEffect(pulsing ? 1.08 : 1)
                .opacity(pulsing ? 0.85 : 1)
                .animation(animated
                           ? .easeOut(duration: 1.5).repeatForever(autoreverses: true).delay(phase)
                           : nil,
                           value: pulsing)
            Circle().fill(core).frame(width: 14, height: 14)
        }
        .position(p)
    }
}

// MARK: - Z2 / Z3 shared motion

/// The gentle 8pt rise-and-fall the comp gives both hero cards (`tw-float`).
private struct FloatingArt<Content: View>: View {
    let period: Double
    let animated: Bool
    @ViewBuilder var content: () -> Content

    @State private var up = false

    var body: some View {
        content()
            .offset(y: up ? -8 : 0)
            .animation(animated
                       ? .easeInOut(duration: period / 2).repeatForever(autoreverses: true)
                       : nil,
                       value: up)
            .onAppear { up = animated }
    }
}

// MARK: - Z2 art

/// A miniature of the partner-mood widget, as it appears on the home screen.
private struct MoodWidgetCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Text("A")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(TweliGradient.partnerAvatar, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Anaya")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.twInk)
                    Text("just now")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.twInkTertiary)
                }
            }

            Text("🌙").font(.system(size: 34)).padding(.top, 14)

            Text("\"missing you\"")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Color.twInk)
                .padding(.top, 6)

            Text("11:41 PM her time")
                .font(.system(size: 11))
                .foregroundStyle(Color.twInkTertiary)
                .padding(.top, 3)
        }
        .padding(18)
        .frame(width: 190, alignment: .leading)
        .background(Color.twElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Brand.indigoLift.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 25, y: 22)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Z3 art

/// A sealed envelope with its lock, and the date it opens.
private struct SealedLetterCard: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.twElevatedWarm)
                .frame(width: 170, height: 120)
                .overlay {
                    // The envelope flap — two strokes meeting at the fold.
                    Path { p in
                        p.move(to: CGPoint(x: 10, y: 14))
                        p.addLine(to: CGPoint(x: 85, y: 68))
                        p.addLine(to: CGPoint(x: 160, y: 14))
                    }
                    .stroke(Brand.pinkLift.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Brand.pinkLift.opacity(0.3), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(TweliGradient.meAvatar, in: Circle())
                        .shadow(color: Brand.pink.opacity(0.4), radius: 9, y: 6)
                        .offset(y: 51)   // comp: centred on 58% of the card height
                }
                .shadow(color: .black.opacity(0.45), radius: 25, y: 22)

            Text("opens Dec 31")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Brand.indigoLift)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Brand.indigoLift.opacity(0.14), in: Capsule())
                .offset(y: 14)
        }
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A sealed letter that opens on December 31")
    }
}

// MARK: - Shared

/// A slow-drifting speck of light. Purely decorative.
private struct TwinkleDot: View {
    let delay: Double
    let period: Double
    let color: Color

    @State private var lit = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 3, height: 3)
            .scaleEffect(lit ? 1.2 : 0.75)
            .opacity(lit ? 1 : 0.18)
            .animation(.easeInOut(duration: period / 2)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                       value: lit)
            .onAppear { lit = true }
            .accessibilityHidden(true)
    }
}

#Preview {
    TutorialView(onFinish: {})
}
