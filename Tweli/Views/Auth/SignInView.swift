//
//  SignInView.swift
//  Tweli
//
//  Comp S3 — "Entry, the front door". Bottom-weighted: the thread and its two
//  endpoints float in the upper third, everything you read and tap sits in the
//  lower half, and there is exactly one promise on the screen.
//
//  Two deliberate departures from the comp:
//
//  1. Apple is the only provider. The comp also draws "Continue with Google"
//     and "Use phone number instead"; neither backend exists, and a button that
//     does nothing is worse than a button that isn't there.
//  2. The comp labels the two endpoints "Toronto · you" and "Abu Dhabi · her".
//     Nobody is signed in yet, so we don't know either city — inventing them
//     would be exactly the fabricated data this build removed. The endpoints
//     read "you" and "them" until there is something true to put there.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()
            glows

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    thread
                        .frame(height: 90)
                        .padding(.horizontal, 28)
                        .position(x: geo.size.width / 2, y: 165)

                    VStack(alignment: .leading, spacing: 0) {
                        headline
                        actions.padding(.top, 30)
                        legal.padding(.top, 14)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.78).delay(0.15)) { appear = true }
        }
    }

    // MARK: - Backdrop

    /// Two soft radial blooms — indigo top-left, pink to the right.
    private var glows: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.twAccent2.opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320, height: 320)
                    .position(x: 40, y: 20)
                Circle()
                    .fill(RadialGradient(colors: [Color.twAccent.opacity(0.16), .clear],
                                         center: .center, startRadius: 0, endRadius: 140))
                    .frame(width: 280, height: 280)
                    .position(x: geo.size.width + 20, y: geo.size.height * 0.18)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - The thread + its two ends

    private var thread: some View {
        VStack(spacing: 2) {
            ThreadArc(progress: appear ? 1 : 0)
                .frame(height: 56)
            HStack {
                endpointLabel("you", tint: Color.twAccent2)
                Spacer()
                endpointLabel("them", tint: Color.twAccentLight)
            }
        }
        .opacity(appear ? 1 : 0)
    }

    private func endpointLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(tint.opacity(0.85))
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tweli")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(6)
                .foregroundStyle(Color.twInkTertiary)

            Text("Closer than\nthe map says.")
                .font(.system(size: 36, weight: .heavy))
                .tracking(-0.8)
                .lineSpacing(2)
                .foregroundStyle(Color.twInk)
                .padding(.top, 12)

            Text("One quiet place for the two of you — moods, letters, and the little reminders that keep a long distance short.")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 14)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 11) {
            SignInWithAppleButton(.continue) { request in
                auth.configure(request)
            } onCompletion: { result in
                auth.handleCompletion(result)
            }
            // Comp: a white pill with black type, on the dark sky.
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(auth.isSigningIn)

            if auth.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finishing sign-in…")
                        .font(.footnote)
                        .foregroundStyle(Color.twInkSecondary)
                }
                .frame(maxWidth: .infinity)
            } else if let error = auth.authError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.twAccentInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

#if DEBUG
            // Developer-only, and absent from every distribution build. Signs in
            // against the local offline store — it seeds no content, so the app
            // still opens on genuinely empty state.
            Button("Dev sign-in") { auth.devSignIn() }
                .font(.footnote)
                .foregroundStyle(Color.twInkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
#endif
        }
        .opacity(appear ? 1 : 0)
    }

    private var legal: some View {
        Text("By continuing you agree to the Terms & Privacy.")
            .font(.system(size: 11))
            .foregroundStyle(Color.twInkQuaternary)
            .frame(maxWidth: .infinity)
            .opacity(appear ? 1 : 0)
    }
}

// MARK: - The arc

/// The thread as it appears on the entry screen: a shallow curve that draws
/// itself left-to-right with a lit dot at each end.
private struct ThreadArc: View {
    /// 0 → undrawn, 1 → fully drawn.
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let start = CGPoint(x: 6, y: h * 0.72)
            let end = CGPoint(x: w - 6, y: h * 0.30)

            ZStack {
                Path { p in
                    p.move(to: start)
                    p.addCurve(to: end,
                               control1: CGPoint(x: w * 0.34, y: h * 0.02),
                               control2: CGPoint(x: w * 0.66, y: h * 1.0))
                }
                .trim(from: 0, to: progress)
                .stroke(TweliGradient.thread,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))

                dot(Color.twAccent2).position(start).opacity(progress > 0.05 ? 1 : 0)
                dot(Color.twAccentLight).position(end).opacity(progress > 0.95 ? 1 : 0)
            }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.7), radius: 7)
    }
}
