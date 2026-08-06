//
//  BeforeYouGoView.swift
//  Tweli
//
//  Comp W2 "Before you go" — the middle gate. It doesn't argue; it counts.
//  Every number here is read from real records, and any line we can't fill
//  honestly is simply not shown.
//
//  The comp's primary action is "Pause instead — sleep for 30 days". Pause is
//  not built, so the softer exit offered here is the one that is: leaving with
//  a keepsake of everything you two wrote.
//

import SwiftUI

struct BeforeYouGoView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var letters: OpenWhenLetterService
    @EnvironmentObject private var moods: MoodService

    @State private var keepsakeURL: URL?
    @State private var goToDelete = false

    private var partnerName: String { couple.partner?.displayName ?? "your partner" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Before you go")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Color.twAccentInk)
                    .padding(.top, 8)

                Text("You two made\nsomething rare.")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .lineSpacing(2)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(tally, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 16))
                            .lineSpacing(3)
                            .foregroundStyle(Color.twInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 26)

                if let last = lastPartnerMood { lastWordCard(last).padding(.top, 22) }

                keepsakeCard.padding(.top, 30)

                Button { goToDelete = true } label: {
                    Text("No — delete my account")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.twInkTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToDelete) { DeleteAccountView() }
    }

    // MARK: - The tally (real records only)

    /// Comp W2's list. Each line is omitted when the number behind it is zero,
    /// so the screen never argues with something that didn't happen.
    private var tally: [String] {
        var out: [String] = []

        if let start = couple.coupleSpace?.createdAt {
            let days = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: start),
                to: Calendar.current.startOfDay(for: Date())).day ?? 0
            if days > 0 { out.append("\(days) days of thread.") }
        }

        let all = letters.letters.count
        if all > 0 {
            let sealed = letters.letters.filter(\.isLocked).count
            out.append(sealed > 0
                ? "\(all) letter\(all == 1 ? "" : "s") — \(sealed) still sealed, waiting for the right night."
                : "\(all) letter\(all == 1 ? "" : "s") between you.")
        }

        let moodCount = moods.moods.count
        if moodCount > 0 {
            out.append("\(moodCount) mood\(moodCount == 1 ? "" : "s") shared.")
        }

        if out.isEmpty { out.append("Everything you've shared here goes with it.") }
        return out
    }

    private var lastPartnerMood: MoodStatus? { moods.partnerMood }

    private func lastWordCard(_ mood: MoodStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The last one, \(mood.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.twInkTertiary)
            Text(mood.note.map { "“\($0)”" } ?? mood.displayLabel)
                .font(.system(size: 17, weight: .semibold))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(Color.twInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            shape.fill(LinearGradient(colors: [.twElevatedWarm, .twElevated],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { shape.strokeBorder(Color.twAccentLight.opacity(0.25), lineWidth: 1) }
        }
    }

    // MARK: - The softer exit

    private var keepsakeCard: some View {
        VStack(spacing: 10) {
            if let keepsakeURL {
                ShareLink(item: keepsakeURL) {
                    primaryLabel("Save your keepsake")
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                Button { keepsakeURL = buildKeepsake() } label: {
                    primaryLabel("Export your letters first")
                }
                .buttonStyle(PressableButtonStyle())
            }

            Text("Nothing is deleted by exporting. Take the words with you — they're yours as much as anyone's.")
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func primaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Brand.cta(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.twAccent.opacity(0.3), radius: 14)
    }

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
}
