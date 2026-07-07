//
//  CountdownView.swift
//  Tweli
//

import SwiftUI

struct CountdownView: View {
    @EnvironmentObject private var service: CountdownService
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let pinned = service.pinned { hero(pinned) }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Upcoming")
                    if service.upcoming.isEmpty {
                        EmptyStateView(icon: "calendar.badge.clock",
                                       title: "Nothing to count down yet",
                                       subtitle: "Create a moment you both can look forward to.",
                                       actionTitle: "Add Countdown") { showAdd = true }
                    } else {
                        ForEach(service.upcoming) { cd in
                            CountdownCardView(countdown: cd) { service.togglePin(cd) }
                        }
                    }
                }
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Countdowns")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddCountdownView() }
    }

    private func hero(_ cd: CountdownItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cd.title).tweliEyebrow(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(cd.daysRemaining)").font(.system(size: 64, weight: .heavy))
                Text("days").font(.title2.weight(.semibold)).opacity(0.9)
            }
            if !cd.note.isEmpty {
                Text(cd.note).font(.subheadline).opacity(0.9)
            }
            ProgressView(value: cd.progress).tint(.white).background(.white.opacity(0.3))
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}
