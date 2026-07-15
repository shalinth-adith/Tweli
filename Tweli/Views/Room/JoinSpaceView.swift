//
//  JoinSpaceView.swift
//  Tweli
//
//  Design 20c/20d — "Join their space". Two dots waiting to be tied: enter the
//  6-character code (as segmented tiles) or paste it, then Join → the joining
//  animation. Redeem logic is unchanged from the code/link flow.
//

import SwiftUI
import UIKit

struct JoinSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""            // up to 6 normalized characters
    @FocusState private var focused: Bool

    /// Where "Create a space instead" routes. Provided by the parent.
    var onSwitchToCreate: (() -> Void)?

    private var normalized: String { FirebaseService.normalizePairCode(code) }
    private var isComplete: Bool { normalized.count == 6 }
    private var youInitial: String { couple.currentUser.initials }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            content
            Spacer()
            footer
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            Spacer()
            HStack(spacing: 6) {
                Capsule().fill(Brand.pink).frame(width: 22, height: 6)
                Capsule().fill(Color.primary.opacity(0.18)).frame(width: 6, height: 6)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // Two dots waiting to be tied — you (dashed) + partner (pink).
            HStack(spacing: 0) {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.tertiary)
                    .frame(width: 58, height: 58)
                    .overlay(Text(youInitial.isEmpty ? "?" : youInitial)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.secondary))
                Image(systemName: "ellipsis")
                    .font(.title3).foregroundStyle(.tertiary).padding(.horizontal, 10)
                AvatarBubble(initial: "", isPartner: true, size: 58)
            }
            .padding(.bottom, 22)

            Text("Join their space")
                .font(.system(size: 28, weight: .heavy)).kerning(-0.6).foregroundStyle(.primary)
            Text("Enter the code your partner shared.\nYour dots get tied together.")
                .font(.system(size: 14.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.top, 8)

            codeTiles.padding(.top, 28)

            if let err = app.joinError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(Brand.pink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16).padding(.horizontal, 24)
            }

            Button {
                if let s = UIPasteboard.general.string { code = extractCode(s) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 14, weight: .semibold))
                    Text("Paste from clipboard").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Brand.indigo)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Brand.indigo.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .padding(.horizontal, 22)
    }

    /// Six tappable tiles backed by a single hidden text field.
    private var codeTiles: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
                .opacity(0.02)
                .onChange(of: code) { _, new in
                    // Keep only valid characters, cap at 6.
                    let cleaned = FirebaseService.normalizePairCode(new)
                    if cleaned != new { code = String(cleaned.prefix(6)) }
                    else if new.count > 6 { code = String(new.prefix(6)) }
                }

            HStack(spacing: 7) {
                let chars = Array(normalized)
                ForEach(0..<6, id: \.self) { i in
                    if i == 3 {
                        Capsule().fill(Color.primary.opacity(0.2)).frame(width: 12, height: 3)
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
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(char == nil ? Color.primary.opacity(0.05) : Color(UIColor.secondarySystemGroupedBackground))
            .frame(width: 44, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(active ? Brand.pink : .clear, lineWidth: 2)
            )
            .overlay(
                Text(char ?? "")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            BrandCTA(title: app.redeemingCode ? "Finding your space…" : "Join their space",
                     loading: app.redeemingCode) {
                Task { await app.joinWithCode(normalized) }
            }
            .disabled(!isComplete || app.redeemingCode)
            .opacity(isComplete ? 1 : 0.5)

            Button("Create a space instead") {
                if let onSwitchToCreate { onSwitchToCreate() } else { dismiss() }
            }
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            .frame(height: 40)
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
    }

    /// Pull a code out of a pasted value — a raw code, or a tweli:// / https link
    /// carrying `?code=…`.
    private func extractCode(_ raw: String) -> String {
        if let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           let c = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "code" })?.value {
            return String(FirebaseService.normalizePairCode(c).prefix(6))
        }
        return String(FirebaseService.normalizePairCode(raw).prefix(6))
    }
}
