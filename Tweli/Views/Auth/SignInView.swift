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
import UIKit

struct SignInView: View {
    /// Comp K1 rather than G1: the app was deleted and put back, so the promise
    /// changes from "we'll start your thread" to "your thread comes back with
    /// you". Everything else — the Apple button, G3, G4 — is deliberately the
    /// same code, because a returning user hits exactly the same failures and
    /// deserves the same diagnostics.
    var returning = false

    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    /// Verification hook (DEBUG only, compiled out of every distribution build):
    /// TWELI_SIGNIN_STATE=signing|failed paints G3 or G4. Apple's sheet cannot be
    /// driven on a simulator, so these two states are otherwise unreachable for a
    /// screenshot.
    private var forcedState: String {
#if DEBUG
        ProcessInfo.processInfo.environment["TWELI_SIGNIN_STATE"] ?? ""
#else
        ""
#endif
    }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()
            glows

            // G3 and G4 take the whole screen rather than appearing as a line
            // under the button. Both are moments the user is waiting on, and a
            // footnote is easy to miss while staring at an Apple sheet.
            if auth.isSigningIn || forcedState == "signing" {
                SigningInState(returning: returning)               // G3
                    .transition(.opacity)
            } else if auth.authError != nil || forcedState == "failed" {
                SignInFailedState(forced: forcedState == "failed")  // G4
                    .transition(.opacity)
            } else {
                entryState                                         // G1
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isSigningIn)
        .animation(.easeInOut(duration: 0.25), value: auth.authError)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.78).delay(0.15)) { appear = true }
        }
    }

    /// G1 — the front door. K1 when the app has been here before.
    private var entryState: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // G1 stacks a few illustrative reminders behind the copy so the
                // promise ("one reminder, both phones") is shown rather than only
                // claimed. K1 replaces them: a returning user does not need the
                // pitch, they need to know their thread survived.
                Group {
                    if returning { returningHero } else { remindersPreview }
                }
                .padding(.horizontal, 28)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.27)

                VStack(alignment: .leading, spacing: 0) {
                    headline
                    actions.padding(.top, 30)
                    if returning { reassurance.padding(.top, 16) }
                    legal.padding(.top, returning ? 12 : 14)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 26)
            }
        }
    }

    // MARK: - K1 · the two ends of a thread that is still there

    /// The comp draws the partner's name on the right ("Anaya — still where you
    /// left her"). It is not drawn here, and that is deliberate: the only store
    /// that survives an uninstall is the Keychain, and the marker Tweli keeps
    /// there is one boolean — no name, no space id, nothing identifying. The
    /// name comes back with the account a few seconds later, on K2 and K3.
    private var returningHero: some View {
        VStack(spacing: 14) {
            ThreadArc(progress: appear ? 1 : 0)
                .frame(height: 62)
                .padding(.horizontal, 6)

            HStack(alignment: .top, spacing: 12) {
                endpointCard(initial: "Y", name: "You",
                             detail: "New phone, new install", tint: Color.twAccent)
                endpointCard(initial: nil, name: "Them",
                             detail: "Still where you left them", tint: Color.twAccent2)
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -10)
    }

    private func endpointCard(initial: String?, name: String,
                              detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Circle()
                    .fill(initial == nil ? tint.opacity(0.16) : tint.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Text(initial ?? "·")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(initial == nil ? tint : Color.white)
                    }
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.twInk)
            }
            Text(detail)
                .font(.system(size: 12))
                .lineSpacing(2)
                .foregroundStyle(Color.twInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(Color.twElevated.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 1)
        }
    }

    /// K1's footnote — the whole reason this screen is calmer than a join flow.
    private var reassurance: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.twAccent2)
                .padding(.top, 1)
            Text("Your pair lives on your account, not on this phone. Nothing to re-enter — no code, no new invite.")
                .font(.system(size: 12.5))
                .lineSpacing(2.5)
                .foregroundStyle(Color.twInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appear ? 1 : 0)
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

    // MARK: - G1 · what the app does, shown not claimed

    /// Comp G1 layers four reminder cards behind the headline. These are
    /// illustrative — nobody is signed in, so there is no real data to draw —
    /// which is why they are visibly a stack of examples rather than a live
    /// list, and why nothing here is ever written to storage.
    private var remindersPreview: some View {
        VStack(spacing: 8) {
            previewCard(who: "You", tint: Color.twAccent,
                        title: "Water her plants", meta: "done 6:40 PM", done: true)
            previewCard(who: "Anaya", tint: Color.twAccent2,
                        title: "Call me after work", meta: "7:00 PM her time")
            previewCard(who: nil, tint: Color.twAccent2,
                        title: "Take your tablet", meta: "every night, 9:00")
            previewCard(who: nil, tint: Color.twAccent,
                        title: "Our anniversary", meta: "in 3 days")
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -10)
        // Decorative: VoiceOver should hear the promise in the headline, not
        // four fictional reminders read out as if they were the user's.
        .accessibilityHidden(true)
    }

    private func previewCard(who: String?, tint: Color,
                             title: String, meta: String, done: Bool = false) -> some View {
        HStack(spacing: 11) {
            Circle()
                .strokeBorder(done ? tint : tint.opacity(0.5), lineWidth: 1.6)
                .background(Circle().fill(done ? tint.opacity(0.9) : .clear))
                .frame(width: 18, height: 18)
                .overlay {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                    }
                }

            VStack(alignment: .leading, spacing: 1) {
                if let who {
                    Text(who)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.twInk.opacity(done ? 0.45 : 1))
                    .strikethrough(done, color: Color.twInkTertiary)
            }
            Spacer(minLength: 6)
            Text(meta)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.twInkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.twElevated.opacity(0.75),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 1)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tweli")
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(6)
                .foregroundStyle(Color.twInkTertiary)

            Text(returning ? "Welcome back." : "Remind us.")
                .font(.system(size: 40, weight: .heavy))
                .tracking(-0.8)
                .lineSpacing(2)
                .foregroundStyle(Color.twInk)
                .padding(.top, 12)

            Text(returning
                 ? "Sign in with the same Apple ID and your thread comes back with you."
                 : "One reminder, both phones. Sign in and we'll start your thread.")
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

// MARK: - G3 · Signing in

/// Comp G3. A whole screen rather than a spinner beside the button: the user is
/// looking at Apple's sheet when this begins, and needs to find their place when
/// they come back.
private struct SigningInState: View {
    /// Same screen, one honest change of tense: on a reinstall nothing is being
    /// set up, it is being found.
    var returning = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draw = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // maxWidth here, not on the enclosing VStack. A shape given only a
            // height takes whatever width it is offered, and a `.frame` on the
            // parent applied after the fact comes too late to widen it — the
            // arc ends up crushed into the left of the screen.
            ThreadArc(progress: draw ? 1 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .padding(.horizontal, 46)

            Text("Signing you in")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.twInk)
                .padding(.top, 28)

            Text(returning ? "Looking for your thread…"
                           : "Setting up your side of the thread…")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.twInkSecondary)
                .padding(.top, 8)

            ProgressView().padding(.top, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { draw = true; return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                draw = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signing you in")
    }
}

// MARK: - G4 · Sign-in failed

/// Comp G4. Names what happened, prints the real code so a support message can
/// be specific, and reassures that nothing was half-created — then offers the
/// two things that actually help.
private struct SignInFailedState: View {
    @EnvironmentObject private var auth: AuthService
    /// True when painted by the DEBUG capture hook rather than a real failure,
    /// so the diagnostic line has something representative to show.
    var forced = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(Color.twWarn.opacity(0.16)).frame(width: 78, height: 78)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.twWarnInk)
            }

            Text(auth.authError ?? "Couldn't reach Apple")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 22)

            Text("Sign-in was cancelled or your connection dropped.\nNothing was created.")
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            if let line = diagnostic {
                Text(line)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.twInkQuaternary)
                    .padding(.top, 14)
            }

            Spacer()

            VStack(spacing: 10) {
                BrandCTA(title: "Try again", showsArrow: false) { auth.dismissAuthError() }

                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Check your connection")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
    }

    /// "Error 1000 · authorization not completed" — only the parts we actually
    /// know. Inventing a code would make a support conversation worse, not better.
    private var diagnostic: String? {
        if forced { return "Error 1000 · authorization not completed" }
        let code = auth.authErrorCode.map { "Error \($0)" }
        let detail = auth.authErrorDetail
        return [code, detail].compactMap { $0 }.joined(separator: " · ").nilWhenEmpty
    }
}

private extension String {
    var nilWhenEmpty: String? { isEmpty ? nil : self }
}
