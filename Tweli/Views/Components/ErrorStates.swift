//
//  ErrorStates.swift
//  Tweli
//
//  The comp's error language, in one place. Its rule: "errors in this app are
//  about a relationship, so they stay warm." Nothing here scolds, nothing here
//  is red except the one destructive action in Our space, and every failure
//  offers a way forward.
//
//    SomethingSnappedView  — comp L13 / N13 / E8, a whole-screen failure
//    OfflineBanner         — comp E1, the stale-data strip on Home
//    FailureToast          — comp L12 / N12 / E4, "Couldn't seal your letter"
//

import SwiftUI

// MARK: - Something snapped (comp L13 / N13 / E8)

/// The generic failure screen: a thread broken in the middle but still glowing
/// at both ends. One primary action, one quiet one, and a reassurance pinned to
/// the bottom.
struct SomethingSnappedView: View {
    @Environment(\.colorScheme) private var scheme

    var detail: String? = nil
    var onRetry: () -> Void
    var onContactSupport: (() -> Void)? = nil

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                BrokenThread()
                    .frame(width: 150, height: 54)

                Text("Something snapped")
                    .font(.system(size: 25, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 28)

                Text("Not between you two — just in the app. Give us a second and try again.")
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Button(action: onRetry) {
                    Text("Try again")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 44)
                        .frame(height: 52)
                        .background(Color.twAccent,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.twAccent.opacity(0.4), radius: 14)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 30)

                if let onContactSupport {
                    Button("Contact support", action: onContactSupport)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.twInkSecondary)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 40)

            VStack {
                Spacer()
                Text(detail ?? "Nothing you shared was lost")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.twInkQuaternary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 44)
            }
        }
    }
}

/// Two dots still lit, the thread between them severed — the comp's one visual
/// for "the app failed, the two of you didn't".
private struct BrokenThread: View {
    @State private var glow = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Left half of the thread, trailing off.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.1, y: h * 0.72))
                    p.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.46),
                                   control: CGPoint(x: w * 0.25, y: h * 0.3))
                }
                .stroke(Color.twAccent2.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Right half, trailing in from the other side.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.6, y: h * 0.54))
                    p.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.28),
                                   control: CGPoint(x: w * 0.75, y: h * 0.7))
                }
                .stroke(Color.twAccent.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))

                dot(color: .twAccent2).position(x: w * 0.1, y: h * 0.72)
                dot(color: .twAccent).position(x: w * 0.9, y: h * 0.28)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func dot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 13, height: 13)
            .shadow(color: color.opacity(glow ? 0.7 : 0.3), radius: glow ? 12 : 6)
    }
}

// MARK: - Offline (comp E1)

/// "You're offline — showing the last thing we knew." Sits above Home's content
/// so the mood card below can be read as history rather than as now.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.twWarn)
            Text("You're offline — showing the last thing we knew.")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.twWarnInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.twWarn.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.twWarn.opacity(0.22), lineWidth: 1)
        }
    }
}

// MARK: - Failure toast (comp L12 / N12 / E4)

/// The card that slides up when something couldn't be sent. It never discards
/// the user's work — the comp's rule is "the draft is sacred", so the secondary
/// action keeps it rather than throwing it away.
struct FailureToast: View {
    let title: String
    let message: String
    var retryTitle = "Retry"
    var dismissTitle = "Keep as draft"
    var onRetry: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(Color.twDanger.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.twDanger)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Color.twInk)
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.twAccent,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: onDismiss) {
                    Text(dismissTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.twInk)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.twInkTertiary.opacity(0.16),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.top, 13)
        }
        .padding(16)
        .background(Color.twElevated2,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
