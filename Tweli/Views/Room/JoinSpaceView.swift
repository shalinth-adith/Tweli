//
//  JoinSpaceView.swift
//  Tweli
//
//  Comps J1–J5 (dark) / JL1–JL5 (light) — "Enter their code".
//
//    J1  empty     — eight cells, the first one lit and breathing
//    J2  typing    — the lit outline slides to the next cell as you type
//    J3  complete  — all cells full, the button wakes, "Looks right — tap to join."
//    J4  wrong     — the cells shake red, and it offers a retry
//    J5  expired   — a different screen entirely: the code was real, just too old
//
//  J6 (accepted) is the confirm step and lives in JoinConfirmView, which the
//  root presents once `pendingInvite` is set.
//
//  Two deliberate departures from the comp, both because the comp was drawn
//  against an older code format than the one the app actually mints:
//
//    - Codes are SIX characters, split 3 + 3 by a hyphen, matching both the comp
//      and every code that has ever existed in the project (FECY63, HW5YEC…).
//      An eight-character format briefly existed in the source but never minted
//      a real code; an eight-cell screen rejected every invite anyone held.
//    - The comp's J5 says "codes last seven days". `publishPairCode` expires them
//      after 48 hours, which is also what the landing page and privacy policy
//      say, so the copy here says 48 hours.
//
//

import SwiftUI
import UIKit

struct JoinSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var shake = 0
    @FocusState private var focused: Bool

    /// Where "Create a space instead" routes. Provided by the parent.
    var onSwitchToCreate: (() -> Void)?

    private let tileCount = FirebaseService.codeLength

    private var normalized: String { FirebaseService.normalizePairCode(code) }
    private var isComplete: Bool { FirebaseService.isPlausiblePairCode(normalized) }
    private var remaining: Int { max(0, tileCount - normalized.count) }
    private var isExpired: Bool { app.joinErrorKind == .expired }
    private var hasError: Bool { app.joinError != nil }

    var body: some View {
        ZStack {
            Color.twBackground.ignoresSafeArea()
            // Comp J1: two large blurred orbs anchored off the bottom corners.
            // They are what stops the near-black background reading as flat.
            AuroraOrbs()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                if isExpired { expiredContent } else { content }
                Spacer(minLength: 12)
                footer
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            app.joinError = nil
            app.joinErrorKind = nil
            // Pre-fill a code delivered by an invite link (universal or tweli://).
            if let pending = app.pendingJoinCode {
                code = pending
                app.pendingJoinCode = nil
            } else {
                focused = true
            }
#if DEBUG
            applyVerificationHooks()
#endif
        }
        .onChange(of: code) { _, _ in
            app.joinError = nil
            app.joinErrorKind = nil
        }
        .onChange(of: app.joinError) { _, err in
            // J4: the cells shake once, then wait. Nothing is cleared — the user
            // usually mistyped one character, not the whole code.
            guard err != nil else { return }
            withAnimation(.default) { shake += 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .frame(width: 40, height: 40)
                    .background(Color.twInk.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            HStack(spacing: 6) {
                Capsule().fill(Color.twAccent).frame(width: 22, height: 6)
                Capsule().fill(Color.twInkTertiary.opacity(0.3)).frame(width: 6, height: 6)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 22).padding(.top, 8)
    }

    // MARK: - J1–J4 · the code screen

    private var content: some View {
        VStack(spacing: 0) {
            Text("Enter their code")
                .font(.system(size: 29, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)

            Text(introCopy)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            codeCells
                .padding(.top, 28)
                .modifier(ShakeEffect(travel: 7, shakes: 3, animatableData: CGFloat(shake)))

            statusLine
                .padding(.top, 16)
                .padding(.horizontal, 10)

            Button {
                if let s = UIPasteboard.general.string { code = extractCode(s) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 14, weight: .semibold))
                    Text("Paste from clipboard").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.twAccent2)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color.twAccent2Soft, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
        .padding(.horizontal, 22)
    }

    /// Comp J1: "…from the invite Anaya sent you." The inviter's name is not
    /// known until the code redeems, so this stays generic until it is.
    private var introCopy: String {
        hasError
            ? "Double-check the code with your partner and try again."
            : "Six characters from the invite your partner sent you."
    }

    /// J1 hint → J3 confirmation → J4 error, in one slot so the layout does not
    /// jump between states.
    @ViewBuilder private var statusLine: some View {
        if let err = app.joinError {
            Text(err)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.twAccentInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else if isComplete {
            // J3 — the moment it looks right, say so.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Looks right — tap to join.")
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(Color.twSuccess)
        } else {
            Text("Codes look like ABC-123")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.twInkTertiary)
        }
    }

    /// Eight tappable cells backed by a single hidden text field, split 4 + 4.
    private var codeCells: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.02)
                .onChange(of: code) { _, new in
                    let cleaned = String(FirebaseService.normalizePairCode(new).prefix(tileCount))
                    if cleaned != new { code = cleaned }
                }

            HStack(spacing: 5) {
                let chars = Array(normalized)
                ForEach(0..<tileCount, id: \.self) { i in
                    if i == tileCount / 2 {
                        Capsule()
                            .fill(Color.twInkTertiary.opacity(0.35))
                            .frame(width: 9, height: 3)
                            .padding(.horizontal, 1)
                    }
                    CodeCell(char: i < chars.count ? String(chars[i]) : nil,
                             active: i == chars.count && focused && !hasError,
                             errored: hasError)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .accessibilityElement()
        .accessibilityLabel("Invite code")
        .accessibilityValue(normalized.isEmpty ? "Empty" : normalized.map(String.init).joined(separator: " "))
    }

    // MARK: - J5 · expired

    /// The comp gives expiry its own screen rather than an error line, because
    /// the user did nothing wrong and retyping cannot help them.
    private var expiredContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.twWarn.opacity(0.16))
                    .frame(width: 78, height: 78)
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.twWarnInk)
            }

            Text("That code has expired")
                .font(.system(size: 27, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 22)

            Text("Ask your partner to send a fresh one —\ncodes last 48 hours.")
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Text(FirebaseService.formatPairCode(normalized))
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.twInkTertiary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Color.twInk.opacity(0.06), in: Capsule())
                .padding(.top, 20)
        }
        .padding(.horizontal, 26)
    }

    // MARK: - Footer

    @ViewBuilder private var footer: some View {
        if isExpired {
            // J5's two ways out. Neither is "try the same code again".
            VStack(spacing: 10) {
                BrandCTA(title: "Enter a different code", showsArrow: false) {
                    code = ""
                    app.joinError = nil
                    app.joinErrorKind = nil
                    focused = true
                }

                ShareLink(item: "Could you send me a fresh Tweli invite code? The last one expired.") {
                    Text("Ask for a new code")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        } else {
            VStack(spacing: 10) {
                BrandCTA(title: app.redeemingCode ? "Finding your space…"
                                                  : (hasError ? "Try again" : "Join the space"),
                         loading: app.redeemingCode) {
                    Task { await app.joinWithCode(normalized) }
                }
                .disabled(!isComplete || app.redeemingCode)
                .opacity(isComplete ? 1 : 0.5)

                Text(helperLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.twInkTertiary)
                    .frame(height: 18)

                Button("Create a space instead") {
                    if let onSwitchToCreate { onSwitchToCreate() } else { dismiss() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInkSecondary)
                .frame(height: 36)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    /// Comp J1/J2: "Two more characters to go"; J4: an offer, not a dead end.
    ///
    /// Gated on `isComplete`, not on `remaining`. `isPlausiblePairCode` accepts
    /// SIX characters as well as eight, so that invites minted before the format
    /// change still redeem — which means a six-character entry is genuinely
    /// submittable while `remaining` still reads 2. Driving this line off
    /// `remaining` alone put "Looks right — tap to join." and "2 more characters
    /// to go" on screen simultaneously, with the button live and two cells empty.
    private var helperLine: String {
        if hasError { return "Ask them to resend the code" }
        if isComplete { return "" }
        switch remaining {
        case 0:  return ""
        case 1:  return "One more character to go"
        default: return "\(remaining) more characters to go"
        }
    }

#if DEBUG
    /// Verification hooks (DEBUG only, compiled out of every distribution build):
    ///
    ///   TWELI_JOIN_CODE=RVW201     pre-fills the cells (J2 partial, J3 complete)
    ///   TWELI_JOIN_ERROR=wrong     paints J4
    ///   TWELI_JOIN_ERROR=expired   paints J5
    ///
    /// Simulators have no touch injection, so these six states are otherwise
    /// impossible to screenshot.
    private func applyVerificationHooks() {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["TWELI_JOIN_CODE"] {
            code = String(FirebaseService.normalizePairCode(raw).prefix(tileCount))
            focused = false
        }
        let kind: FirebaseService.PairCodeError? = switch env["TWELI_JOIN_ERROR"] {
        case "wrong":   .notFound
        case "expired": .expired
        default:        nil
        }
        guard let kind else { return }
        // Setting `code` above schedules `.onChange(of: code)`, which clears any
        // error — that is correct for a real user typing, and fatal here if the
        // error is set first. Applying it after the change has settled is what
        // makes J4/J5 actually paint instead of falling back to J3.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            app.joinErrorKind = kind
            app.joinError = kind.errorDescription
        }
    }
#endif

    /// Pull a code out of a pasted value — a raw code, or a tweli:// / https link
    /// carrying `?code=…`.
    private func extractCode(_ raw: String) -> String {
        if let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           let c = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "code" })?.value {
            return String(FirebaseService.normalizePairCode(c).prefix(tileCount))
        }
        return String(FirebaseService.normalizePairCode(raw).prefix(tileCount))
    }
}

// MARK: - One code cell

/// Comp J1–J4: a 52×68 rounded cell. The focused one wears a rotating conic
/// border — in the comp a `conic-gradient` under `tw-spinborder`, here the same
/// gradient rotated behind a stroked mask, which is the SwiftUI equivalent and
/// costs one layer instead of an animated image.
private struct CodeCell: View {
    let char: String?
    let active: Bool
    let errored: Bool

    @State private var angle: Double = 0
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)

    var body: some View {
        ZStack {
            shape
                .fill(char == nil ? Color.twInk.opacity(0.06) : Color.twElevated)

            if active {
                spinningBorder
            } else {
                shape.strokeBorder(
                    errored ? Color.twAccent.opacity(0.7) : Color.twHairline,
                    lineWidth: errored ? 1.5 : 1
                )
            }

            Text(char ?? "")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.twInk)
                .contentTransition(.numericText())
        }
        .frame(width: 38, height: 52)
        .scaleEffect(active && breathe ? 1.04 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: breathe)
        .onChange(of: active) { _, on in breathe = on && !reduceMotion }
        .onAppear {
            breathe = active && !reduceMotion
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }

    private var spinningBorder: some View {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: Color(UIColor.tw(0xFF375F)), location: 0.17),
                .init(color: Color(UIColor.tw(0xFF7A93)), location: 0.33),
                .init(color: Color(UIColor.tw(0x7B79FF)), location: 0.55),
                .init(color: .clear, location: 0.83),
            ]),
            center: .center,
            angle: .degrees(angle)
        )
        .mask { shape.strokeBorder(lineWidth: 2) }
    }
}

// MARK: - Backdrop

/// Comp J1: two blurred colour orbs low on the screen. Purely decorative, and
/// static — an animated blur this large is the most expensive thing on the
/// screen and the comp's drift is imperceptible at this size.
private struct AuroraOrbs: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Circle()
                    .fill(Color.twAccent2.opacity(0.38))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 70)
                    .position(x: w * 0.1, y: h * 0.95)
                Circle()
                    .fill(Color.twAccent.opacity(0.34))
                    .frame(width: w * 0.88, height: w * 0.88)
                    .position(x: w * 0.92, y: h * 0.97)
                    .blur(radius: 70)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shake (comp J4)

/// A short horizontal shake used when a code doesn't match. Deliberately brief —
/// the comp's rule is that errors in this app stay warm.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0)
        )
    }
}
