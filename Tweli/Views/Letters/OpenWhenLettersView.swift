//
//  OpenWhenLettersView.swift
//  Tweli
//
//  2-column grid of envelope cards with a floating "+" button, matching the design.
//

import SwiftUI

struct OpenWhenLettersView: View {
    @EnvironmentObject private var service: OpenWhenLetterService
    @State private var showAdd = false
    @State private var reading: OpenWhenLetter?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                if service.letters.isEmpty {
                    EmptyStateView(icon: "envelope",
                                   title: "No letters yet",
                                   subtitle: "Write an open-when letter for a moment that matters.",
                                   actionTitle: "Add Letter") { showAdd = true }
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(service.letters.enumerated()), id: \.element.id) { index, letter in
                            Button { open(letter) } label: {
                                OpenWhenLetterCardView(letter: letter,
                                                       accent: index.isMultiple(of: 2) ? .twAccent : .twAccent2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, TweliMetrics.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 90)
                }
            }

            // Floating action button
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.twAccent, in: Circle())
                    .shadow(color: Color.twAccent.opacity(0.4), radius: 12, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .padding(24)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Open-When Letters")
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
