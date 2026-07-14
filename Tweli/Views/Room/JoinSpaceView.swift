//
//  JoinSpaceView.swift
//  Tweli
//
//  Design 12b — join an existing space with the partner's 6-char invite code
//  (or by pasting the full invite link).
//

import SwiftUI
import UIKit

struct JoinSpaceView: View {
    @EnvironmentObject private var app: AppViewModel

    @State private var input = ""
    @FocusState private var focused: Bool

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Pasted https invite link (iCloud share URL) — opened via the OS.
    private var pastedURL: URL? {
        guard let url = URL(string: trimmed),
              url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    /// Code extracted from a pasted tweli://join?code=… link. Any other tweli://
    /// URL (e.g. the widget's tweli://sendlove) is NOT an invite.
    private var deepLinkCode: String? {
        guard let url = URL(string: trimmed), url.scheme == "tweli", url.host == "join",
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return nil }
        return code
    }

    /// 6 valid characters → treat as a pairing code.
    private var normalizedCode: String { FirebaseService.normalizePairCode(trimmed) }
    private var isCode: Bool { pastedURL == nil && deepLinkCode == nil && normalizedCode.count == 6 }
    /// The single code to redeem, whichever way it arrived.
    private var codeToRedeem: String? { deepLinkCode ?? (isCode ? normalizedCode : nil) }
    private var isValid: Bool { codeToRedeem != nil || pastedURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    codeField
                    if let err = app.joinError { errorCard(err) }
                    else if isValid { matchedPreview }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
            }
            joinBar
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Join space")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in app.joinError = nil }
        .onAppear { app.joinError = nil }   // don't show a stale error from an earlier attempt
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.twAccent2.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.twAccent2)
            }
            Text("Enter your invite code").font(.system(size: 24, weight: .heavy)).foregroundStyle(.primary)
            Text("Type the 6-character code your partner shared — or paste their invite link.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var codeField: some View {
        HStack(spacing: 10) {
            Image(systemName: "number").foregroundStyle(Color.twInkTertiary)
            TextField("7GK-4PB or invite link", text: $input)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .focused($focused)
            Button("Paste") {
                if let s = UIPasteboard.general.string { input = s }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.twAccent)
        }
        .padding(15)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var matchedPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.title3).foregroundStyle(Color.twSuccess)
            Text(isCode ? "Code looks good. Tap Join to find your space."
                        : "Looks like a valid invite link. Tap Join to open it.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title3).foregroundStyle(Color.twWarn)
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var joinBar: some View {
        PrimaryButton(title: app.redeemingCode ? "Finding your space…" : "Join space",
                      systemImage: app.redeemingCode ? "hourglass" : "heart.fill") {
            if let code = codeToRedeem {
                // Code (typed or from a tweli://join link) → public DB lookup →
                // share metadata → confirm-join sheet. One redeem path.
                Task { await app.joinWithCode(code) }
            } else if let url = pastedURL {
                // iCloud share link: the OS routes it back to us with the
                // share metadata → the confirm-join sheet appears.
                UIApplication.shared.open(url)
            }
        }
        .disabled(!isValid || app.redeemingCode)
        .opacity(isValid ? 1 : 0.5)
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
    }
}
