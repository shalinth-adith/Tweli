//
//  AccountView.swift
//  Tweli
//
//  Comp W1 "Your account" — the first of three gates on the way out, and the
//  only screen in the app whose job is to offer you something smaller than the
//  thing you came here to do.
//
//  Two departures from the comp, both because a button that does nothing is
//  worse than no button:
//   · "Take a break" and "Mute everything for a while" are not built, so they
//     are not drawn. The section keeps its name and its one real occupant.
//   · The footnote in the comp promises the letters you sent stay hers. That is
//     true only if you say so on W3 — by default deletion removes everything you
//     authored — so the wording here points at that choice instead of promising
//     an outcome the next screen might not deliver.
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var letters: OpenWhenLetterService
    @EnvironmentObject private var moods: MoodService

    @State private var keepsakeURL: URL?
    @State private var showFarewell = false

    private var partnerName: String { couple.partner?.displayName ?? "your partner" }
    private var hasPartner: Bool { couple.partner != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your account")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 8)

                threadCard.padding(.top, 22)

                sectionLabel("Keepsake")
                group {
                    exportRow
                }

                sectionLabel("Permanent")
                group {
                    Button { showFarewell = true } label: {
                        row(title: "Delete my account",
                            subtitle: "Everything, forever — after one last look",
                            tint: .twDanger)
                    }
                    .buttonStyle(.plain)
                }

                Text(footnote)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(Color.twInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Your account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showFarewell) { BeforeYouGoView() }
    }

    // MARK: - The thread

    private var threadCard: some View {
        HStack(spacing: 13) {
            HStack(spacing: -10) {
                avatar(couple.currentUser.initials, gradient: TweliGradient.meAvatar)
                    .zIndex(1)
                avatar(couple.partner?.initials ?? "?", gradient: TweliGradient.partnerAvatar)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pairTitle)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let since = threadedSince {
                    Text(since)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 18)
    }

    private func avatar(_ initials: String, gradient: LinearGradient) -> some View {
        Circle()
            .fill(gradient)
            .frame(width: 40, height: 40)
            .overlay {
                Text(initials.isEmpty ? "·" : initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            // The comp rings each avatar in the card colour so they read as
            // overlapping tokens rather than one blob.
            .overlay { Circle().strokeBorder(Color.twElevated, lineWidth: 2) }
    }

    private var pairTitle: String {
        hasPartner ? "You & \(partnerName)" : "Your space"
    }

    /// "Threaded since January 5 · 214 days" — omitted entirely if we don't know.
    private var threadedSince: String? {
        guard let start = couple.coupleSpace?.createdAt else { return nil }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let date = start.formatted(.dateTime.month(.wide).day())
        return "Threaded since \(date) · \(days) day\(days == 1 ? "" : "s")"
    }

    // MARK: - Export

    private var exportRow: some View {
        Group {
            if let keepsakeURL {
                ShareLink(item: keepsakeURL) {
                    row(title: "Export your letters",
                        subtitle: "A keepsake of everything you two wrote",
                        tint: .twInk)
                }
                .buttonStyle(.plain)
            } else {
                Button { keepsakeURL = buildKeepsake() } label: {
                    row(title: "Export your letters",
                        subtitle: "A keepsake of everything you two wrote",
                        tint: .twInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Assembles the keepsake from records already on the device, so it works
    /// offline and still works while an account is being deleted.
    private func buildKeepsake() -> URL? {
        let text = KeepsakeExport.build(
            spaceTitle: couple.coupleSpace?.title ?? "Our space",
            myName: couple.currentUser.displayName.isEmpty ? "You" : couple.currentUser.displayName,
            partnerName: couple.partner?.displayName ?? "Your partner",
            startedOn: couple.coupleSpace?.createdAt,
            letters: letters.letters,
            moods: moods.moods,
            myUserId: couple.currentUser.id
        )
        return KeepsakeExport.writeToTemporaryFile(text,
                                                   partnerName: couple.partner?.displayName ?? "")
    }

    // MARK: - Pieces

    private var footnote: String {
        hasPartner
            ? "Deleting your account never deletes \(partnerName)'s. You'll choose on the next screen whether the letters you wrote stay with them."
            : "Deleting your account removes this space and everything in it."
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .tweliCard(radius: 18)
    }

    private func row(title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.twInkQuaternary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
