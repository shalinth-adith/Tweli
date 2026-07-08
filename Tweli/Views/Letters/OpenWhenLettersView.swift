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

/// The opened-letter reading view (design 6a) — sender header, titled white
/// message card, and Keep / Write-back actions.
private struct LetterReaderView: View {
    let letter: OpenWhenLetter
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showWriteBack = false
    @State private var kept = false

    private var senderName: String {
        letter.createdBy == app.currentUser.id ? "You" : (app.partner?.displayName ?? "Your partner")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Sender header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.54), .twAccent],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(Text(String(senderName.prefix(1))).font(.headline).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(senderName).font(.headline).foregroundStyle(.primary)
                            Text(letter.createdAt.formatted(.relative(presentation: .named)))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)

                    Text(letter.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 14)

                    // Message card
                    VStack(alignment: .leading, spacing: 16) {
                        Text(letter.message)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("— \(senderName)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(18)
                    .background(Color.twElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                }
                .padding(18)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomActions }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label("Letters", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                    }
                }
            }
            .sheet(isPresented: $showWriteBack) { AddOpenWhenLetterView() }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button { kept.toggle() } label: {
                Label(kept ? "Kept" : "Keep", systemImage: kept ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.primary)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            Button { showWriteBack = true } label: {
                Label("Write back", systemImage: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(Color.twAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}
