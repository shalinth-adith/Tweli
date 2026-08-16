//
//  PairGoneView.swift
//  Tweli
//
//  Comps K5 / KL5 — "she left while you were away".
//
//  The sibling of E6 (PartnerLeftView), for the case where it happened with the
//  app off the phone. E6 can be gentle in the present tense because the user is
//  watching it happen; this one has to deliver news, and the difference shows in
//  the copy: it says when, and it says what is still here.
//
//  Every claim on this screen is conditional on evidence:
//
//  - The name appears only when the space document carries `leftByName`. When
//    the space itself was swept away there is no name on record, and the
//    headline says "your pair" rather than naming somebody it cannot name.
//  - The date appears only when `leftAt` was stamped.
//  - "Kept for you" appears only when something was actually kept.
//
//  AppViewModel only routes here on `.partnerLeft`, or on `.nothingToRestore`
//  when this device is known to have been paired. A failed lookup
//  (`.unreachable`) never reaches this screen — telling someone their partner
//  left because the network dropped would be the worst bug in the app.
//

import SwiftUI

struct PairGoneView: View {
    let detail: PairGoneDetail

    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    private var name: String? {
        detail.partnerName?.trimmingCharacters(in: .whitespaces).nilIfEmpty
    }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                brokenThread
                    .padding(.bottom, 4)

                Text(headline)
                    .font(.system(size: 29, weight: .heavy))
                    .tracking(-0.7)
                    .lineSpacing(1)
                    .foregroundStyle(Color.twInk)
                    .multilineTextAlignment(.center)
                    // Same reason as K3: the name is user-supplied, and a long
                    // one must shrink rather than break mid-word.
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .padding(.top, 28)

                Text(explanation)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                if detail.hasKeepsakes {
                    keptCard.padding(.top, 26)
                }

                Spacer(minLength: 0)

                actions.padding(.bottom, 26)
            }
            .padding(.horizontal, 32)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    private var headline: String {
        guard let name else { return "There's no pair to\nreturn to" }
        return "\(name) isn't on the\nother end anymore"
    }

    /// Assembled from what is on record and nothing else. Each clause is
    /// dropped independently, so a missing date doesn't cost the sentence.
    private var explanation: String {
        var parts: [String] = []

        if let leftAt = detail.leftAt {
            let when = leftAt.formatted(.dateTime.day().month(.wide))
            parts.append(name.map { "\($0) left the thread on \(when), while the app was off your phone." }
                         ?? "The thread was left on \(when), while the app was off your phone.")
        } else if let name {
            parts.append("\(name) left the thread while the app was off your phone.")
        } else {
            // No record at all: the space is gone. Say that, and don't guess at
            // who ended it or when — we genuinely do not know.
            parts.append("We signed you in, but the space you were in is no longer there.")
        }

        if detail.leftAt != nil || name != nil {
            parts.append("We signed you in, but there's no pair to return to.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Broken thread

    /// Your end still lit, theirs gone, the run between them trailing off. The
    /// same visual grammar as E6 so the two screens read as one idea.
    private var brokenThread: some View {
        HStack(spacing: 0) {
            ProfileAvatar(profile: couple.currentUser, size: 58)
                .zIndex(1)

            ZStack {
                Rectangle()
                    .fill(Color.twAccent.opacity(0.45))
                    .frame(width: 26, height: 2)
                    .offset(x: -13)
                Rectangle()
                    .fill(Color.twInkTertiary.opacity(0.28))
                    .frame(width: 30, height: 1.5)
                    .mask {
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { _ in Rectangle().frame(width: 4) }
                        }
                    }
                    .offset(x: 15)
            }
            .frame(width: 56)

            Circle()
                .fill(Color.twInkTertiary.opacity(0.14))
                .frame(width: 58, height: 58)
                .overlay {
                    Text(name?.prefix(1).uppercased() ?? "·")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.twInkQuaternary)
                }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Kept

    private var keptCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Kept for you")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(Color.twAccentInk)

            Text(keptLine)
                .font(.system(size: 13.5))
                .lineSpacing(2.5)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.twElevated.opacity(0.8),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 1)
        }
    }

    /// Counts only. The leave function deliberately leaves the letters they
    /// sealed for you behind, and finished reminders are shared history — so
    /// both are real, and nothing is claimed beyond them.
    private var keptLine: String {
        var clauses: [String] = []
        if detail.lettersKept > 0 {
            let who = name.map { " \($0) sent you" } ?? " sent to you"
            clauses.append("The \(detail.lettersKept) \(detail.lettersKept == 1 ? "letter" : "letters")\(who)")
        }
        if detail.remindersKept > 0 {
            clauses.append("every reminder you finished together")
        }
        return clauses.joined(separator: ", and ")
            + ". Yours to read, nothing new arriving."
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 11) {
            if detail.hasKeepsakes {
                // Keeps the space bound so the letters are readable, then hands
                // over to the ordinary app. The tabs are honest here: it is half
                // a thread, and every screen already has an empty state for that.
                BrandCTA(title: "Read what's kept", showsArrow: false) { app.endRestore() }

                Button("Start a new thread") { app.startFreshAfterPairGone() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInkSecondary)
                    .frame(height: 40)
            } else {
                // Nothing was kept, so there is nothing to go and read. Offering
                // "Read what's kept" over an empty space would be a dead end.
                BrandCTA(title: "Start a new thread", showsArrow: false) {
                    app.startFreshAfterPairGone()
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
