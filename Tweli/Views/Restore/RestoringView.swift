//
//  RestoringView.swift
//  Tweli
//
//  Comps K2 / KL2 — "the thread redrawing itself".
//
//  This is the loading state, not a screen in front of one. A returning user
//  waits on exactly one thing after signing in — their thread coming back — and
//  a bare spinner would hide the only interesting part: what is being found.
//
//  Every row corresponds to real work in `AppViewModel.runRestore()`. Nothing
//  here animates ahead of the thing it describes, and a row that finds nothing
//  says so (`.skipped`) rather than ticking green over an empty result.
//
//  Light mode (KL2) is the same view: the palette in DesignSystem.swift resolves
//  every `Color.tw…` token against the active trait collection.
//

import SwiftUI

struct RestoringView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appear = false
    @State private var drawThread = false

    private var myName: String {
        let name = couple.currentUser.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "" : name
    }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                threadHero
                    .frame(height: 120)
                    .padding(.horizontal, 44)

                Text("Finding your thread")
                    .font(.system(size: 27, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 30)

                Text(subtitle)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)

                checklist
                    .padding(.top, 34)

                Spacer(minLength: 0)

                Text(reassurance)
                    .font(.system(size: 12.5))
                    .lineSpacing(2)
                    .foregroundStyle(Color.twInkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 32)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
            guard !reduceMotion else { drawThread = true; return }
            withAnimation(.easeInOut(duration: 1.5).delay(0.2)) { drawThread = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Restoring your thread")
    }

    /// Names the person only when we actually know their name. On a reinstall
    /// the display name arrives with the Apple credential, so it usually does —
    /// but "Signed in as ." would be worse than no line at all.
    private var subtitle: String {
        myName.isEmpty
            ? "Pulling everything back onto this phone."
            : "Signed in as \(myName). Pulling everything\nback onto this phone."
    }

    /// The comp's closing reassurance. Kept general until the partner's name is
    /// known — which, on this screen, is the moment the "pair found" row ticks.
    private var reassurance: String {
        if let partner = couple.partner?.displayName, !partner.isEmpty {
            return "\(partner) isn't notified. To them, nothing happened."
        }
        return "Nobody is notified. To them, nothing happened."
    }

    // MARK: - Hero

    /// Two endpoints and the thread being redrawn between them.
    private var threadHero: some View {
        ZStack {
            RestoringThread()
                .trim(from: 0, to: drawThread ? 1 : 0)
                .stroke(TweliGradient.thread,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            HStack {
                AvatarBubble(initial: couple.currentUser.initials, size: 44)
                Spacer()
                partnerEnd
            }
        }
    }

    /// Solid once the pair is found, a dashed outline while it is still being
    /// looked for — the same distinction K5 draws, for the same reason.
    private var partnerEnd: some View {
        Group {
            if let partner = couple.partner {
                AvatarBubble(initial: partner.initials, isPartner: true, size: 44)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .strokeBorder(Color.twAccent2.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.twAccent2.opacity(0.08)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: couple.partner)
    }

    // MARK: - Checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(app.restoreSteps) { step in
                RestoreStepRow(step: step)
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
        .animation(.easeInOut(duration: 0.3), value: app.restoreSteps)
    }
}

// MARK: - One row

private struct RestoreStepRow: View {
    let step: RestoreStep
    @State private var spin = false

    var body: some View {
        HStack(spacing: 12) {
            marker
                .frame(width: 22, height: 22)

            Text(step.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(titleColour)

            Spacer(minLength: 8)

            if let detail = step.detail {
                Text(detail)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.twInkTertiary)
                    .monospacedDigit()
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var marker: some View {
        switch step.state {
        case .done:
            ZStack {
                Circle().fill(Color.twSuccess)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    // Ink ON the success fill, not `.white`: in light mode the
                    // fill is pale enough that a white tick disappears.
                    .foregroundStyle(Color.twBackground)
            }
        case .skipped:
            // Deliberately not a tick. Nothing of this kind existed, and a green
            // check would claim something came back that never did.
            Circle()
                .strokeBorder(Color.twInkQuaternary.opacity(0.5), lineWidth: 1.6)
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.twInkQuaternary)
                }
        case .running:
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(Color.twAccent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        spin = true
                    }
                }
        case .waiting:
            Circle()
                .strokeBorder(Color.twHairline, lineWidth: 1.6)
        }
    }

    private var titleColour: Color {
        switch step.state {
        case .done:               Color.twInk
        case .running:            Color.twInk
        case .waiting, .skipped:  Color.twInkTertiary
        }
    }

    private var accessibilityLabel: String {
        let state: String = switch step.state {
        case .done: "done"
        case .running: "in progress"
        case .waiting: "waiting"
        case .skipped: "nothing to restore"
        }
        return [step.title, state, step.detail].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - The thread

/// The curve between the two endpoints — the same shallow S the entry screen
/// draws, sized for this layout.
private struct RestoringThread: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 22, y: h * 0.66))
        p.addCurve(to: CGPoint(x: w - 22, y: h * 0.34),
                   control1: CGPoint(x: w * 0.34, y: h * 0.98),
                   control2: CGPoint(x: w * 0.62, y: h * 0.04))
        return p
    }
}
