//
//  DatesSheetView.swift
//  Tweli
//
//  Dates are no longer a tab — they live in this half-sheet, opened from the
//  "Dates" card on Home. It presents the next date, the list of planned dates
//  (tap a row for details, long-press to complete/cancel), and a "+" to add a
//  new one. Opens at the medium detent; drag up for the full height.
//

import SwiftUI

struct DatesSheetView: View {
    @EnvironmentObject private var service: VirtualDateService
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let next = service.next {
                        NavigationLink(value: next) { nextHero(next) }
                            .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Planned")
                        if service.planned.isEmpty {
                            EmptyStateView(icon: "calendar.badge.plus",
                                           title: "No dates planned",
                                           subtitle: "Plan a little something to look forward to together.",
                                           actionTitle: "Add a date") { showAdd = true }
                        } else {
                            ForEach(service.planned) { date in
                                NavigationLink(value: date) {
                                    VirtualDateRowView(date: date)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Mark completed") { service.setStatus(date, .completed) }
                                    Button("Cancel date", role: .destructive) { service.setStatus(date, .cancelled) }
                                }
                            }
                        }
                    }
                }
                .padding(TweliMetrics.screenPadding)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .navigationTitle("Dates")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: VirtualDateItem.self) { VirtualDateDetailView(date: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddVirtualDateView() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func nextHero(_ date: VirtualDateItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next date").tweliEyebrow(.white.opacity(0.85))
            Text(date.title).font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
            Text(date.whenLabel).font(.subheadline).foregroundStyle(.white.opacity(0.9))
            if !date.notes.isEmpty {
                Text(date.notes).font(.caption).foregroundStyle(.white.opacity(0.85)).padding(.top, 2)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
