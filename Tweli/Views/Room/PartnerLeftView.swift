//
//  PartnerLeftView.swift
//  Tweli
//
//  Comp M4 / ML4 — "She left the thread · the thread comes apart, slowly".
//  Supersedes E6, which said the same thing in one sentence and a button.
//
//  Raised by AppViewModel.partnerLeftName, which is set when the space-doc
//  listener sees the other member remove themselves (FirebaseService.announceLeave
//  and the `leaveSpace` function). By the time this is on screen the server has
//  already pushed M1/M2 to this device, so for most people this screen is the
//  second time they hear it, not the first.
//
//  Two rules this screen is built around:
//
//  1. Nothing here blames anyone, and the primary action is an open door.
//  2. Every number is real or absent. `Summary` makes each row optional and the
//     row is dropped when we cannot answer it, rather than rendering a zero. "0
//     letters they wrote you" is a sentence this screen must never produce.
//

import SwiftUI

struct PartnerLeftView: View {
    /// The name of whoever left, so the headline can say who.
    let partnerName: String
    /// What is left behind. Any nil row is omitted — see the note above.
    var summary: Summary = .init()

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService

    /// The three facts M4 states about what survives the departure.
    ///
    /// A plain value type on purpose: it keeps the view renderable from a
    /// preview or a test without a live space behind it, which is how the
    /// M4/ML4 capture shots are produced.
    struct Summary {
        /// Letters they sealed for you. The `leaveSpace` function deliberately
        /// keeps these — the exit flow promises exactly that — so this row is
        /// the screen's strongest reassurance and worth leading with.
        var lettersKept: Int? = nil
        /// Their final mood, frozen where they left it.
        var lastCardLabel: String? = nil
        var lastCardEmoji: String? = nil
        /// Days the space existed, from `CoupleSpace.createdAt`.
        var daysTogether: Int? = nil
        /// When they closed their side, for the opening line.
        var leftAt: Date? = nil
    }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                severedThread
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)

                Text("\(partnerName) left\nthe thread")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.7)
                    .lineSpacing(2)
                    .foregroundStyle(Color.twInk)

                Text(openingLine)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .frame(maxWidth: 300, alignment: .leading)

                if !rows.isEmpty {
                    statusCard.padding(.top, 22)
                }

                Spacer(minLength: 24)

                Button { app.openLettersAfterPartnerLeft() } label: {
                    Text("Read their letters")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.twBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.twInk,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())

                // "Start a new thread" is deliberately the quiet half of a
                // sentence rather than a second button. The comp puts no
                // deadline on this screen, and two equally-weighted buttons
                // would read as a choice that has to be made now.
                Group {
                    Text("Take your time. ")
                        .foregroundStyle(Color.twInkTertiary)
                    + Text("Start a new thread")
                        .foregroundStyle(Color.twAccentInk)
                        .fontWeight(.semibold)
                    + Text(" whenever you want.")
                        .foregroundStyle(Color.twInkTertiary)
                }
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 11)
                .contentShape(Rectangle())
                .onTapGesture { app.startFreshAfterPartnerLeft() }
            }
            .padding(.horizontal, 26)
            .padding(.top, 96)
            .padding(.bottom, 32)
        }
    }

    /// "They closed their side this morning" only if we know when. Otherwise the
    /// sentence simply starts at the part we can stand behind.
    private var openingLine: String {
        let tail = "No new cards, no new letters. Your widget will go quiet after today."
        guard let leftAt = summary.leftAt else { return tail }
        return "They closed their side \(Self.whenPhrase(for: leftAt)). \(tail)"
    }

    /// Coarse on purpose — "this morning", not "at 09:14". The exact minute
    /// someone left is not a detail this screen should press on.
    static func whenPhrase(for date: Date, now: Date = Date(),
                           calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let hour = calendar.component(.hour, from: date)
            switch hour {
            case 0..<12:  return "this morning"
            case 12..<17: return "this afternoon"
            default:      return "this evening"
            }
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 { return "\(days) days ago" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Status rows

    private struct Row: Identifiable {
        let id = UUID()
        let emoji: String
        let text: String
        let tag: String
        var dimmed = false
    }

    private var rows: [Row] {
        var out: [Row] = []
        if let n = summary.lettersKept, n > 0 {
            out.append(Row(emoji: "💌",
                           text: n == 1 ? "1 letter they wrote you"
                                        : "\(n) letters they wrote you",
                           tag: "kept"))
        }
        if let label = summary.lastCardLabel {
            out.append(Row(emoji: summary.lastCardEmoji ?? "🌙",
                           text: label.isEmpty ? "Their last card" : "Their last card · \(label)",
                           tag: "frozen"))
        }
        if let days = summary.daysTogether, days > 0 {
            out.append(Row(emoji: "🕒",
                           text: days == 1 ? "1 day together" : "\(days) days together",
                           tag: "ended today", dimmed: true))
        }
        return out
    }

    private var statusCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 11) {
                    Text(row.emoji).font(.system(size: 16))
                    Text(row.text)
                        .font(.system(size: 14))
                        .foregroundStyle(row.dimmed ? Color.twInkSecondary : Color.twInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.tag)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.twInkTertiary)
                }
                .padding(.vertical, 13)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color.twInk.opacity(0.07))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 18)
        .background(Color.twElevated,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.twInk.opacity(0.09), lineWidth: 0.5)
        }
    }

    // MARK: - The thread coming apart

    /// Yours still lit, theirs gone grey, and the line between them broken at
    /// the far end rather than the middle — the comp's "comes apart, slowly".
    private var severedThread: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 52, y: 96))
                p.addCurve(to: CGPoint(x: 228, y: 44),
                           control1: CGPoint(x: 104, y: 122),
                           control2: CGPoint(x: 168, y: 22))
            }
            .trim(from: 0, to: 0.72)   // stops short: it no longer reaches them
            .stroke(TweliGradient.thread,
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            Circle()
                .fill(TweliGradient.meAvatar)
                .frame(width: 34, height: 34)
                .overlay {
                    Text(couple.currentUser.initials.isEmpty ? "·" : couple.currentUser.initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.twAccent.opacity(0.45), radius: 13)
                .position(x: 53, y: 97)

            Circle()
                .fill(Color.twInkTertiary.opacity(0.06))
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().strokeBorder(Color.twInkTertiary.opacity(0.16), lineWidth: 1.5)
                }
                .overlay {
                    Text(partnerName.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.twInkQuaternary)
                }
                .position(x: 227, y: 43)
        }
        .frame(width: 280, height: 130)
    }
}
