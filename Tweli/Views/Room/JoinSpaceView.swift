//
//  JoinSpaceView.swift
//  Tweli
//
//  Comp A6 "Enter the code" and its failure state E2 "Wrong code".
//
//  Eight tiles split 4 + 4 by a hyphen, matching the ABCD-1234 shape codes are
//  minted in (FirebaseService.makeCode). A wrong code shakes, explains, and
//  keeps the door open — it never scolds. Legacy 6-character codes still redeem,
//  so an invite sent before the format change continues to work.
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
    private var youInitial: String { couple.currentUser.initials }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            content
            Spacer(minLength: 12)
            footer
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            app.joinError = nil
            // Pre-fill a code delivered by an invite link (universal or tweli://).
            if let pending = app.pendingJoinCode {
                code = pending
                app.pendingJoinCode = nil
            } else {
                focused = true
            }
        }
        .onChange(of: code) { _, _ in app.joinError = nil }
        .onChange(of: app.joinError) { _, err in
            // E2: the tiles shake once, then wait. Nothing is cleared — the user
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .frame(width: 34, height: 34)
                    .background(Color.twInkTertiary.opacity(0.22), in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Capsule().fill(Color.twAccent).frame(width: 22, height: 6)
                Capsule().fill(Color.twInkTertiary.opacity(0.3)).frame(width: 6, height: 6)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            Text("Join a space")
                .font(.system(size: 12, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.twAccentInk)

            Text("Enter the code")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.7)
                .foregroundStyle(Color.twInk)
                .padding(.top, 8)

            Text(introCopy)
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            codeTiles
                .padding(.top, 28)
                .modifier(ShakeEffect(travel: 7, shakes: 3, animatableData: CGFloat(shake)))

            if let err = app.joinError {
                Text(err)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.twAccentInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .padding(.horizontal, 10)
            } else {
                Text("Codes look like ABCD-1234")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .padding(.top, 16)
            }

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
            .padding(.top, 20)
        }
        .padding(.horizontal, 22)
    }

    private var introCopy: String {
        app.joinError == nil
            ? "Your partner sent you an 8-character code. Type it here and the thread ties itself."
            : "Double-check the code with your partner and try again."
    }

    /// Eight tappable tiles backed by a single hidden text field, split 4 + 4.
    private var codeTiles: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
                .opacity(0.02)
                .onChange(of: code) { _, new in
                    let cleaned = String(FirebaseService.normalizePairCode(new).prefix(tileCount))
                    if cleaned != new { code = cleaned }
                }

            HStack(spacing: 5) {
                let chars = Array(normalized)
                ForEach(0..<tileCount, id: \.self) { i in
                    if i == 4 {
                        Capsule()
                            .fill(Color.twInkTertiary.opacity(0.35))
                            .frame(width: 10, height: 3)
                            .padding(.horizontal, 2)
                    }
                    tile(char: i < chars.count ? String(chars[i]) : nil,
                         active: i == chars.count && focused)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func tile(char: String?, active: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return shape
            .fill(char == nil ? Color.twInkTertiary.opacity(0.08) : Color.twElevated)
            .frame(width: 34, height: 48)
            .overlay {
                shape.strokeBorder(active ? Color.twAccent
                                          : (app.joinError != nil ? Color.twAccent.opacity(0.45)
                                                                  : Color.twHairline),
                                   lineWidth: active ? 2 : 1)
            }
            .overlay {
                Text(char ?? "")
                    .font(.system(size: 21, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.twInk)
            }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            BrandCTA(title: app.redeemingCode ? "Finding your space…"
                                              : (app.joinError == nil ? "Join our space" : "Try again"),
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

    /// Comp A6: "Two more characters to go"; E2: an offer, not a dead end.
    private var helperLine: String {
        if app.joinError != nil { return "Ask them to resend the code" }
        switch remaining {
        case 0:  return ""
        case 1:  return "One more character to go"
        default: return "\(remaining) more characters to go"
        }
    }

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

// MARK: - Shake (comp E2)

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
