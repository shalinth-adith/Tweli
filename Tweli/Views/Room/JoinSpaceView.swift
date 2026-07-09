//
//  JoinSpaceView.swift
//  Tweli
//
//  Design 12b — join an existing space by pasting the invite link.
//

import SwiftUI
import UIKit

struct JoinSpaceView: View {
    @EnvironmentObject private var app: AppViewModel

    @State private var link = ""
    @FocusState private var focused: Bool

    /// A CloudKit share can only be accepted by opening its link (the OS then
    /// hands the app the share) — so we validate that this is a real URL.
    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { URL(string: trimmedLink)?.scheme?.hasPrefix("http") == true }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    linkField
                    if isValid { matchedPreview }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
            }
            joinBar
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Join space")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.twAccent2.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.twAccent2)
            }
            Text("Paste your invite link").font(.system(size: 24, weight: .heavy)).foregroundStyle(.primary)
            Text("Open the link your partner shared, or paste it below to join your shared space.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var linkField: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(Color.twInkTertiary)
            TextField("https://tweli.app/join/…", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
            Button("Paste") {
                if let s = UIPasteboard.general.string { link = s }
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
            Text("Looks like a valid invite. Tap Join to open it and confirm.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var joinBar: some View {
        PrimaryButton(title: "Join space", systemImage: "heart.fill") {
            // Opening the CloudKit share link routes it through the OS, which hands
            // the app the share metadata → the confirm-join sheet appears.
            if let url = URL(string: trimmedLink) { UIApplication.shared.open(url) }
        }
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
    }
}
