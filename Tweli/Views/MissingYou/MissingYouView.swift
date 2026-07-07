//
//  MissingYouView.swift
//  Tweli
//

import SwiftUI

struct MissingYouView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MissingYouService
    @State private var justSent: String?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(MissingYouPreset.allCases) { preset in
                        Button { send(preset) } label: { presetTile(preset) }
                            .buttonStyle(.plain)
                    }
                }
                if !service.history.isEmpty { historySection }
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Missing You")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let justSent {
                Text("Sent: \(justSent)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.twAccent, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Send a little love").font(.title2.weight(.bold))
            Text("A tiny ping travels straight to \(app.partner?.displayName ?? "your partner").")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func presetTile(_ preset: MissingYouPreset) -> some View {
        VStack(spacing: 10) {
            Image(systemName: preset.sfSymbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.twAccent)
            Text(preset.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.twAccentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recent")
            ForEach(service.history) { ping in
                HStack(spacing: 12) {
                    Image(systemName: ping.sentBy == app.currentUser.id ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption).foregroundStyle(ping.sentBy == app.currentUser.id ? Color.twAccent2 : Color.twAccent)
                    Text(ping.message).font(.subheadline).foregroundStyle(.primary)
                    Spacer()
                    Text(ping.relativeLabel).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(12)
                .tweliCard()
            }
        }
    }

    private func send(_ preset: MissingYouPreset) {
        service.send(preset, senderName: app.currentUser.displayName)
        withAnimation(.snappy) { justSent = preset.rawValue }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { justSent = nil }
        }
    }
}
