//
//  OpenWhenLettersView.swift
//  Tweli
//
//  Comp L6 / N6 / B4 — "Letters arrive sealed; they open only when their moment
//  comes." A single-column list in three groups:
//
//    Ready to open  — the warm, ringed, glowing row. Tap to read.
//    Still sealed   — quiet rows with an indigo wax seal and a days-left pill.
//    Opened         — kept forever, faded back.
//
//  Empty state is comp E7: an invitation, not a void.
//

import SwiftUI

struct OpenWhenLettersView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: OpenWhenLetterService

    @State private var showAdd = false
    @State private var reading: OpenWhenLetter?

    /// Sealed letters whose moment has arrived — the only lit thing on the screen.
    private var ready: [OpenWhenLetter] {
        service.letters.filter { !$0.isOpened && !$0.isLocked }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var sealed: [OpenWhenLetter] {
        service.letters.filter(\.isLocked)
            .sorted { ($0.unlockDate ?? .distantFuture) < ($1.unlockDate ?? .distantFuture) }
    }
    private var opened: [OpenWhenLetter] {
        service.letters.filter(\.isOpened)
            .sorted { ($0.openedAt ?? .distantPast) > ($1.openedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if service.letters.isEmpty {
                    emptyState
                } else {
                    if !ready.isEmpty {
                        sectionLabel("Ready to open", top: 24)
                        VStack(spacing: 10) { ForEach(ready) { readyRow($0) } }
                    }
                    if !sealed.isEmpty {
                        sectionLabel("Still sealed", top: 22)
                        VStack(spacing: 8) { ForEach(sealed) { sealedRow($0) } }
                    }
                    if !opened.isEmpty {
                        sectionLabel("Opened", top: 22)
                        VStack(spacing: 8) { ForEach(opened) { openedRow($0) } }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) { AddOpenWhenLetterView() }
        .sheet(item: $reading) { LetterReaderView(letter: $0) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom) {
                Text("Letters")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                Spacer()
                Button { showAdd = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil").font(.system(size: 12, weight: .bold))
                        Text("Write").font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.twAccent, in: Capsule())
                    .shadow(color: Color.twAccent.opacity(0.35), radius: 11)
                }
                .buttonStyle(PressableButtonStyle())
            }
            Text("Letters arrive sealed — they open only when their moment comes.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.twInkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String, top: CGFloat) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, top)
            .padding(.bottom, 10)
    }

    // MARK: - Rows

    /// Comp: warm gradient, pink ring, glowing pink seal, an "Open" pill.
    private func readyRow(_ letter: OpenWhenLetter) -> some View {
        Button { open(letter) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(TweliGradient.meAvatar).frame(width: 48, height: 48)
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.twAccent.opacity(0.5), radius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(letter.title)
                        .font(.system(size: 16.5, weight: .heavy))
                        .tracking(-0.3)
                        .foregroundStyle(Color.twInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(byline(letter, suffix: "sealed \(relative(letter.createdAt))"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text("Open")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.twAccentInk)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.twAccentSoft, in: Capsule())
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
                shape.fill(LinearGradient(colors: [.twElevatedWarm, .twElevated],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { shape.strokeBorder(Color.twAccentLight.opacity(0.35), lineWidth: 1) }
                    .shadow(color: Color.twAccent.opacity(0.16), radius: 17, y: 6)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Comp: plain card, indigo wax-seal disc, days-left pill on the right. Not
    /// tappable — there is nothing behind a sealed letter yet.
    private func sealedRow(_ letter: OpenWhenLetter) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.twAccent2Soft).frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.twAccent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(letter.title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .lineLimit(2)
                Text(byline(letter, suffix: unlockLabel(letter)))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let days = daysUntilUnlock(letter) {
                Text(days == 1 ? "1 day" : "\(days) days")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.twInkSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.twInkTertiary.opacity(0.14), in: Capsule())
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 18)
    }

    /// Comp B4: "Opened Jul 1 · kept forever", faded back.
    private func openedRow(_ letter: OpenWhenLetter) -> some View {
        Button { open(letter) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.twInkTertiary.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "envelope.open")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.twInkTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(letter.title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(Color.twInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(openedLabel(letter))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tweliCard(radius: 18)
        }
        .buttonStyle(.plain)
        .opacity(0.75)
    }

    // MARK: - Empty state (comp E7)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(Color.twAccentSoft).frame(width: 64, height: 64)
                Image(systemName: "envelope")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.twAccentInk)
            }
            .padding(.bottom, 4)

            Text("No letters yet")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.twInk)
            Text("Write the first one. Seal it for a rainy day, her birthday, or the flight home — it waits as long as it needs to.")
                .font(.system(size: 14.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { showAdd = true } label: {
                Text("Write the first letter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Brand.cta(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.twAccent.opacity(0.32), radius: 15)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 10)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 20)
        .padding(.top, 26)
    }

    // MARK: - Copy helpers

    private func byline(_ letter: OpenWhenLetter, suffix: String) -> String {
        let who = letter.createdBy == app.currentUser.id
            ? "You wrote this"
            : "From \(app.partner?.displayName ?? "your partner")"
        return suffix.isEmpty ? who : "\(who) · \(suffix)"
    }

    private func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private func unlockLabel(_ letter: OpenWhenLetter) -> String {
        guard let d = letter.unlockDate else { return "" }
        return "unlocks \(d.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func openedLabel(_ letter: OpenWhenLetter) -> String {
        guard let at = letter.openedAt else { return byline(letter, suffix: "kept forever") }
        return "Opened \(at.formatted(.dateTime.month(.abbreviated).day())) · kept forever"
    }

    private func daysUntilUnlock(_ letter: OpenWhenLetter) -> Int? {
        guard let d = letter.unlockDate else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: d)).day ?? 0
        return max(0, days)
    }

    private func open(_ letter: OpenWhenLetter) {
        guard !letter.isLocked else { return }
        if !letter.isOpened {
            service.markOpened(letter)
            // Opening a letter your person wrote for you is the second-best
            // moment in the app to be asked for a rating. Arming only on the
            // FIRST open keeps re-reads from re-arming it.
            app.review.arm(.letterOpened)
        }
        reading = service.letters.first { $0.id == letter.id } ?? letter
    }
}

// MARK: - Reader (comp L7 / N7)

/// The opened letter. The one screen in the app that is not on the app's own
/// surface: it is warm stationery in BOTH modes — "warm paper" by day, the same
/// page "candlelit" at night — because a letter should never look like a card.
private struct LetterReaderView: View {
    let letter: OpenWhenLetter
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showWriteBack = false
    @State private var kept = false

    private var isMine: Bool { letter.createdBy == app.currentUser.id }
    private var senderName: String {
        isMine ? app.currentUser.displayName : (app.partner?.displayName ?? "Your partner")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    senderHeader
                    Text(letter.title)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.4)
                        .lineSpacing(3)
                        .foregroundStyle(Color.twInk)
                        .padding(.horizontal, 2)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                    paper
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomActions }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Letters").font(.system(size: 17))
                        }
                        .foregroundStyle(Color.twAccent)
                    }
                }
            }
            .sheet(isPresented: $showWriteBack) { AddOpenWhenLetterView() }
        }
    }

    private var senderHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isMine ? TweliGradient.meAvatar : TweliGradient.partnerAvatar)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(isMine ? app.currentUser.initials : (app.partner?.initials ?? "?"))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: (isMine ? Color.twAccent : Color.twAccent2).opacity(0.4), radius: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(senderName)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.twInk)
                Text(openedLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.twInkTertiary)
            }
        }
    }

    private var openedLine: String {
        guard let at = letter.openedAt else { return "Just opened" }
        let today = Calendar.current.isDateInToday(at)
        let night = Calendar.current.component(.hour, from: at) >= 21
            || Calendar.current.component(.hour, from: at) < 5
        let when = today ? (night ? "tonight" : "today")
                         : at.formatted(.dateTime.month(.abbreviated).day())
        return "Opened \(when), \(at.formatted(date: .omitted, time: .shortened))"
    }

    /// Comp: a 165° warm gradient with a gold hairline, a soft radial bloom in
    /// the top-right corner, warm brown ink and a heavier signature.
    private var paper: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(letter.message)
                .font(.system(size: 16))
                .lineSpacing(10)          // comp line-height 1.65
                .foregroundStyle(Color.twPaperInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("— \(senderName)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.twPaperInkStrong)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [.twPaperTop, .twPaperBottom],
                           startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .topTrailing) {
                    // The candle in the corner.
                    Circle()
                        .fill(RadialGradient(colors: [Color(UIColor.tw(0xFFBE5A, 0.12)),
                                                      Color(UIColor.tw(0xFFBE5A, 0))],
                                             center: .center, startRadius: 0, endRadius: 70))
                        .frame(width: 140, height: 140)
                        .offset(x: 20, y: -40)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.twPaperRing, lineWidth: 1)
        }
        .shadow(color: Color.twWarn.opacity(0.1), radius: 15, y: 6)
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button { kept.toggle() } label: {
                Label(kept ? "Kept" : "Keep", systemImage: kept ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.twInkTertiary.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            Button { showWriteBack = true } label: {
                Label("Write back", systemImage: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.twAccent,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: Color.twAccent.opacity(0.35), radius: 12)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}
