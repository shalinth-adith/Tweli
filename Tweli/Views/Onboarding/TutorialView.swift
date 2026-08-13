//
//  TutorialView.swift
//  Tweli
//
//  Comp 0Z — the entry tutorial. Four animated scenes shown once, after the
//  splash and BEFORE sign-in, skippable at any point:
//
//    Z1  The thread    — dots drift in, the line draws, then a spark runs it forever
//    Z2  Moods, live   — her moods cycle on a floating widget
//    Z3  The distance  — an arc bridges two cities, a light travels it
//    Z4  Letters       — the envelope unseals itself, over and over
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
//  Every loop here is gated on `reduceMotion`. These scenes run indefinitely, so
//  honouring that setting is not a nicety: four simultaneous infinite animations
//  are exactly what the setting exists to stop.
//

import SwiftUI

struct TutorialView: View {

    /// Called on Skip and on "Start your thread" alike — both mean "done".
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private static let pageCount = 4

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            twinkles

            VStack(spacing: 0) {
                skipRow

                // Chrome (dots + CTA) is hoisted out of the pager so it stays
                // put while pages move. The comp draws it on every page in the
                // same position, so this is faithful and avoids four copies.
                TabView(selection: $page) {
                    threadPage.tag(0)
                    moodPage.tag(1)
                    distancePage.tag(2)
                    letterPage.tag(3)
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
            // TWELI_TUTORIAL_PAGE=<0-3> opens straight to a page, because
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

    /// Comp: two or three specks per scene, at different positions. Drawn once
    /// against the whole screen rather than per page, so they don't restart
    /// their loops every time the pager moves.
    private var twinkles: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                TwinkleDot(delay: 0.7, period: 4.2, color: Brand.indigoLift, animated: !reduceMotion)
                    .position(x: w * 0.14, y: h * 0.10)
                TwinkleDot(delay: 1.6, period: 3.6, color: Brand.pinkLift, animated: !reduceMotion)
                    .position(x: w * 0.84, y: h * 0.16)
                TwinkleDot(delay: 2.3, period: 5.1, color: Color.twInk.opacity(0.5), animated: !reduceMotion)
                    .position(x: w * 0.08, y: h * 0.30)
                TwinkleDot(delay: 0.2, period: 4.8, color: Brand.indigoLift, animated: !reduceMotion)
                    .position(x: w * 0.91, y: h * 0.24)
            }
        }
        .allowsHitTesting(false)
    }

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

    /// Title + body, identical across the four pages.
    private func copyBlock(_ title: String, _ body: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 31, weight: .heavy))
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
             body: "A private line between your phone and theirs.\nNothing here is ever public.")
    }

    // MARK: - Z2 · Moods on the widget

    private var moodPage: some View {
        page(art: FloatingArt(period: 4.5, animated: !reduceMotion) {
                 MoodWidgetCard(animated: !reduceMotion)
             },
             title: "Her day, on your\nhome screen.",
             body: "Two taps to set a mood — it lands on their\nwidget the same second, anywhere on earth.")
    }

    // MARK: - Z3 · The distance

    private var distancePage: some View {
        page(art: DistanceGlobeArt(animated: !reduceMotion),
             title: "The distance gets\na little smaller.",
             body: "See their city, their time of day — and the\ncountdown to when you meet next.")
    }

    // MARK: - Z4 · Letters

    private var letterPage: some View {
        page(art: FloatingArt(period: 5, animated: !reduceMotion) {
                 UnsealingLetterCard(animated: !reduceMotion)
             },
             title: "Letters that wait\nfor the right night.",
             body: "Seal one for a birthday, a hard day, or just\nbecause. It stays locked until its moment.")
    }
}

// MARK: - Z1 art

/// The signature curve drawing itself between the pink dot (you) and the indigo
/// one (them), then a spark running the finished line forever. Comp geometry is
/// a 280×150 SVG; kept in that coordinate space so the control points can be
/// read straight off the comp.
private struct ThreadArt: View {
    let animated: Bool

    @State private var progress: CGFloat = 0
    @State private var pulsing = false
    @State private var driftedIn = false

    private static let size = CGSize(width: 280, height: 150)
    private static let start = CGPoint(x: 30, y: 106)
    private static let end   = CGPoint(x: 250, y: 44)

    private static var threadPath: Path {
        var p = Path()
        p.move(to: start)
        p.addCurve(to: end,
                   control1: CGPoint(x: 100, y: 30),
                   control2: CGPoint(x: 180, y: 128))
        return p
    }

    var body: some View {
        // The frame has to be established BEFORE these children lay out. A
        // `.frame` applied to the enclosing ZStack comes too late: `.position`
        // expands to whatever was proposed, and the path's absolute comp
        // coordinates would then be drawn against the full screen and cropped
        // away. Overlaying a sized `Color.clear` proposes exactly 280×150.
        Color.clear
            .frame(width: Self.size.width, height: Self.size.height)
            .overlay {
                Self.threadPath
                    .trim(from: 0, to: progress)
                    .stroke(TweliGradient.thread,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Comp: the dots drift in from their own side before the line draws.
                dot(at: Self.start, core: Brand.pinkLift,
                    halo: Color(UIColor.tw(0xFF5E7E, 0.18)), phase: 0)
                    .offset(x: driftedIn ? 0 : -26)
                    .opacity(driftedIn ? 1 : 0)
                dot(at: Self.end, core: Color(UIColor.tw(0x8E8CFF)),
                    halo: Color(UIColor.tw(0x8E8CFF, 0.18)), phase: 1.5)
                    .offset(x: driftedIn ? 0 : 26)
                    .opacity(driftedIn ? 1 : 0)

                // The spark only exists once the line is complete — it is the
                // "and then it keeps going" beat, not part of the drawing.
                if animated && progress >= 1 {
                    SparkAlongPath(path: Self.threadPath, period: 2.8, delay: 0.8)
                }
            }
        .onAppear {
            guard animated else { progress = 1; driftedIn = true; return }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) { driftedIn = true }
            // Comp: 2.4s ease, 1.1s in — the pause before it starts is what
            // makes the line read as being drawn rather than revealed.
            withAnimation(.easeInOut(duration: 2.4).delay(1.1)) { progress = 1 }
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
                .scaleEffect(pulsing ? 1.12 : 1)
                .opacity(pulsing ? 0.8 : 1)
                .animation(animated
                           ? .easeOut(duration: 1.5).repeatForever(autoreverses: true).delay(phase)
                           : nil,
                           value: pulsing)
            Circle()
                .fill(core)
                .frame(width: 14, height: 14)
                .shadow(color: core.opacity(0.8), radius: 8)
        }
        .position(p)
    }
}

/// A bright mote travelling a path on a loop — the comp's `offset-path` +
/// `tw-spark` pairing, which SwiftUI expresses as a trimmed-path lookup.
///
/// `Path.trimmedPath(from:to:)` collapsed to a zero-length segment has a
/// `currentPoint` on the curve, which is how the position is sampled. This is
/// cheaper than flattening the curve ourselves and stays exact for any path.
private struct SparkAlongPath: View {
    let path: Path
    let period: Double
    var delay: Double = 0
    var color: Color = .white
    var glow: Color = Color(UIColor.tw(0xFF96B4, 0.75))

    @State private var t: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate - delay
            let phase = elapsed.truncatingRemainder(dividingBy: period) / period
            // Ease in-out so the mote slows at both ends, as the comp does.
            let eased = CGFloat(0.5 - cos(max(0, phase) * 2 * .pi) / 2)
            let point = pointOnPath(eased)
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: glow, radius: 7)
                .position(point)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pointOnPath(_ fraction: CGFloat) -> CGPoint {
        let clamped = min(max(fraction, 0), 1)
        return path.trimmedPath(from: 0, to: clamped).currentPoint
            ?? path.trimmedPath(from: 0, to: 0.0001).currentPoint
            ?? .zero
    }
}

// MARK: - Z2 / Z4 shared motion

/// The gentle 8pt rise-and-fall the comp gives the hero cards (`tw-float`).
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
/// The comp cycles three moods through it on a 10.5s loop, which is the whole
/// point of the scene: it shows the widget as something that *changes*.
private struct MoodWidgetCard: View {
    let animated: Bool

    @State private var index = 0

    private struct Mood {
        let emoji: String, text: String, time: String
    }

    private static let moods = [
        Mood(emoji: "🌙", text: "\"missing you\"",    time: "11:41 PM her time"),
        Mood(emoji: "🥰", text: "\"saw your letter\"", time: "8:02 AM her time"),
        Mood(emoji: "☕", text: "\"slow morning\"",    time: "9:15 AM her time"),
    ]

    /// Comp: `tw-cycle3` over 10.5s across three panes.
    private static let dwell: Double = 3.5

    private var mood: Mood { Self.moods[index] }

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
                Spacer(minLength: 6)
                // The comp's live dot — she is online right now.
                Circle()
                    .fill(Color.twSuccess)
                    .frame(width: 8, height: 8)
            }

            // Fixed height so the card doesn't resize as the copy changes
            // length — the comp holds a 96px well for exactly this reason.
            VStack(alignment: .leading, spacing: 0) {
                Text(mood.emoji).font(.system(size: 34))
                Text(mood.text)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 6)
                Text(mood.time)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.twInkTertiary)
                    .padding(.top, 3)
            }
            .frame(height: 96, alignment: .topLeading)
            .id(index)
            .transition(.opacity)
            .padding(.top, 10)
        }
        .padding(18)
        .frame(width: 200, alignment: .leading)
        .background(Color.twElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Brand.indigoLift.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 28, y: 24)
        .task {
            guard animated else { return }
            // A plain sleep loop rather than a repeating Timer: it is cancelled
            // automatically when the page leaves the hierarchy.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.dwell))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    index = (index + 1) % Self.moods.count
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A widget showing your partner's current mood")
    }
}

// MARK: - Z3 art

/// The globe with an arc bridging two cities and a light travelling it. Comp
/// geometry is a 240×240 box; the meridians are four ellipses on a slow spin,
/// which reads as rotation without the cost of an actual sphere.
private struct DistanceGlobeArt: View {
    let animated: Bool

    @State private var progress: CGFloat = 0
    @State private var spin: Double = 0

    private static let side: CGFloat = 232
    private static let cityA = CGPoint(x: 58, y: 150)
    private static let cityB = CGPoint(x: 186, y: 86)

    private static var arcPath: Path {
        var p = Path()
        p.move(to: cityA)
        p.addCurve(to: cityB,
                   control1: CGPoint(x: 92, y: 62),
                   control2: CGPoint(x: 152, y: 58))
        return p
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                globeBody
                meridians
                arc
                cityDot(at: Self.cityA, color: Brand.pinkLift)
                cityDot(at: Self.cityB, color: Color(UIColor.tw(0x8E8CFF)))
                if animated && progress >= 1 {
                    SparkAlongPath(path: Self.arcPath, period: 3.0, delay: 0.4,
                                   glow: Color(UIColor.tw(0xC7B6FF, 0.8)))
                }
            }
            .frame(width: 240, height: 240)
            .scaleEffect(Self.side / 240)
            .frame(width: Self.side, height: Self.side)

            Text("Chennai ↔ Toronto · 13,929 km")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.twInkSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(Color.twInk.opacity(0.07), in: Capsule())
        }
        .onAppear {
            guard animated else { progress = 1; return }
            withAnimation(.easeInOut(duration: 2.2).delay(0.8)) { progress = 1 }
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                spin = 360
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A globe with an arc drawn between two cities, 13,929 kilometres apart")
    }

    private var globeBody: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(UIColor.tw(0x2E2452)),
                             Color(UIColor.tw(0x191330)),
                             Color(UIColor.tw(0x100C1E))],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 0, endRadius: 190)
            )
            .overlay { Circle().strokeBorder(Brand.indigoLift.opacity(0.2), lineWidth: 1) }
            .shadow(color: .black.opacity(0.5), radius: 30, y: 24)
    }

    /// Four ellipses on a slow rotation. The comp spins the whole group, so the
    /// horizontal ones sweep and the vertical ones tilt — cheap, and convincing.
    private var meridians: some View {
        ZStack {
            Ellipse().strokeBorder(Brand.indigoLift.opacity(0.18), lineWidth: 1)
                .frame(width: 224, height: 80)
            Ellipse().strokeBorder(Brand.indigoLift.opacity(0.18), lineWidth: 1)
                .frame(width: 224, height: 156)
            Ellipse().strokeBorder(Brand.indigoLift.opacity(0.18), lineWidth: 1)
                .frame(width: 80, height: 224)
            Ellipse().strokeBorder(Brand.indigoLift.opacity(0.18), lineWidth: 1)
                .frame(width: 156, height: 224)
        }
        .rotationEffect(.degrees(spin))
        .clipShape(Circle())
    }

    private var arc: some View {
        Self.arcPath
            .trim(from: 0, to: progress)
            .stroke(
                LinearGradient(colors: [Brand.pinkLift, Color(UIColor.tw(0x8E8CFF))],
                               startPoint: .bottomLeading, endPoint: .topTrailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: 240, height: 240)
    }

    private func cityDot(at p: CGPoint, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.9), radius: 7)
            .position(p)
            .frame(width: 240, height: 240)
    }
}

// MARK: - Z4 art

/// A letter that unseals itself on a loop: the flap lifts, the page rises out,
/// then it all settles back. The comp runs this on a 7s cycle so the scene
/// answers "what is an open-when letter?" without the reader tapping anything.
private struct UnsealingLetterCard: View {
    let animated: Bool

    @State private var open = false

    private static let w: CGFloat = 190
    private static let h: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                // Envelope back.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color(UIColor.tw(0x2A1222)),
                                                  Color(UIColor.tw(0x1A1030))],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Brand.pinkLift.opacity(0.3), lineWidth: 1)
                    }

                // The page — rises out of the envelope as the flap opens.
                paper
                    .offset(y: open ? -34 : 6)
                    .scaleEffect(open ? 1 : 0.97)

                // Front pocket, drawn over the page so it tucks behind.
                PocketShape()
                    .fill(LinearGradient(colors: [Color(UIColor.tw(0x31162A)),
                                                  Color(UIColor.tw(0x201338))],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 74)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // The flap, hinged at the top edge.
                FlapShape()
                    .fill(LinearGradient(colors: [Color(UIColor.tw(0x3A1548)),
                                                  Color(UIColor.tw(0x2A1030))],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 64)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .rotation3DEffect(.degrees(open ? -168 : 0),
                                      axis: (x: 1, y: 0, z: 0),
                                      anchor: .top,
                                      perspective: 0.6)

                // The wax seal rides the flap down and back.
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(colors: [Brand.pinkLift, Color(UIColor.tw(0xFF375F))],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .shadow(color: Color(UIColor.tw(0xFF375F, 0.45)), radius: 9, y: 6)
                    .offset(y: -12)
                    .opacity(open ? 0 : 1)
                    .scaleEffect(open ? 0.7 : 1)
            }
            .frame(width: Self.w, height: Self.h)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 26, y: 22)

            Text("open when you miss me")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Brand.indigoLift)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Brand.indigoLift.opacity(0.14), in: Capsule())
                .offset(y: 16)
        }
        .padding(.bottom, 16)
        .task {
            guard animated else { return }
            // Comp: 7s cycle — sealed, opening, held open, closing.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.1)) { open = true }
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.1)) { open = false }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A sealed letter labelled open when you miss me, unsealing itself")
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 7) {
            line(widthFraction: 0.70, strong: true)
            line(widthFraction: 0.88)
            line(widthFraction: 0.60)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: Self.w - 36, height: 92, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color.twPaperTop, Color.twPaperBottom],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .shadow(color: .black.opacity(0.35), radius: 7, y: 4)
    }

    private func line(widthFraction: CGFloat, strong: Bool = false) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(strong ? Color.twPaperInkStrong : Color.twPaperInk)
                .frame(width: geo.size.width * widthFraction, height: 5)
        }
        .frame(height: 5)
    }
}

/// The envelope's front pocket: a rectangle with a V cut out of its top edge.
private struct PocketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.52))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The flap: a downward-pointing triangle hinged along the top edge.
private struct FlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Shared

/// A slow-drifting speck of light. Purely decorative.
private struct TwinkleDot: View {
    let delay: Double
    let period: Double
    let color: Color
    var animated: Bool = true

    @State private var lit = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 3, height: 3)
            .scaleEffect(lit ? 1.2 : 0.75)
            .opacity(lit ? 1 : 0.18)
            .animation(animated
                       ? .easeInOut(duration: period / 2)
                            .repeatForever(autoreverses: true)
                            .delay(delay)
                       : nil,
                       value: lit)
            .onAppear { lit = animated }
            .accessibilityHidden(true)
    }
}

#Preview {
    TutorialView(onFinish: {})
}
