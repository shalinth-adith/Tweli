//
//  OpenWhenLettersView.swift
//  Tweli
//

import SwiftUI

struct OpenWhenLettersView: View {
    @EnvironmentObject private var service: OpenWhenLetterService
    @State private var showAdd = false
    @State private var reading: OpenWhenLetter?

    var body: some View {
        ScrollView {
            if service.letters.isEmpty {
                EmptyStateView(icon: "envelope",
                               title: "No letters yet",
                               subtitle: "Write an open-when letter for a moment that matters.",
                               actionTitle: "Add Letter") { showAdd = true }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(service.letters) { letter in
                        Button { open(letter) } label: { OpenWhenLetterRowView(letter: letter) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, TweliMetrics.screenPadding)
                .padding(.top, 4)
            }
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Open-When Letters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddOpenWhenLetterView() }
        .sheet(item: $reading) { letter in LetterReaderView(letter: letter) }
    }

    private func open(_ letter: OpenWhenLetter) {
        guard !letter.isLocked else { return }
        if !letter.isOpened { service.markOpened(letter) }
        reading = service.letters.first { $0.id == letter.id } ?? letter
    }
}

/// The reading sheet shown when a letter is opened.
private struct LetterReaderView: View {
    let letter: OpenWhenLetter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.twAccent)
                        .padding(.top, 20)
                    Text(letter.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    Text(letter.message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(24)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
