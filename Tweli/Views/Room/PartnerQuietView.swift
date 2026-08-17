//
//  PartnerQuietView.swift
//  Tweli
//
//  Comp M5 / ML5 — "Her side went quiet · app deleted, pair still open".
//
//  Raised by AppViewModel.partnerQuietSince, set when the space doc carries a
//  `quietSince` stamp for the partner. The server writes that stamp when a push
//  to them bounces off a dead registration token.
//
//  WHAT THIS SCREEN IS ALLOWED TO SAY
//
//  The comp's copy reads "She deleted the app four days ago." This screen does
//  NOT say that, deliberately. A dead FCM token is the only signal iOS gives us
//  here, and it is not proof of an uninstall: a rotated token, a restore from
//  backup, or an app evicted after long disuse all produce exactly the same
//  error. Telling someone their partner deleted the app — in the one place it
//  would hurt most — on evidence that thin is not a trade this app makes.
//
//  So the copy states only the part we can stand behind: their side has been
//  quiet since a date we actually observed. That is the same rule K5 follows,
//  where `.unreachable` never claims a partner left.
//
//  This is NOT a departure. The partner is still in `memberUids`, the pair is
//  intact, and everything sent still waits for them — which is the reassurance
//  the screen exists to deliver.
//

import SwiftUI

struct PartnerQuietView: View {
    let partnerName: String
    /// When their device stopped being reachable. Observed, not inferred.
    let quietSince: Date
    /// Their last mood, frozen where they left it.
    var lastCardEmoji: String? = nil
    var lastCardLabel: String? = nil
    var lastCardAt: Date? = nil
    var lastCardPlace: String? = nil

    /// "Leave them a letter anyway" — the whole point is that this still works.
    var onWriteLetter: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var couple: CoupleSpaceService

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                quietThread
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 26)

                Text("STILL PAIRED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.twWarnInk)

                Text("\(partnerName)'s side\nwent quiet")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.6)
                    .lineSpacing(2)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 10)

                Text(explanation)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                if lastCardLabel != nil {
                    lastCard.padding(.top, 22)
                }

                waitingNotice.padding(.top, 14)

                Spacer(minLength: 24)

                Button(action: onWriteLetter) {
                    Text("Leave them a letter anyway")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(TweliGradient.hero,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: Color.twAccent.opacity(0.32), radius: 14, y: 8)
                }
                .buttonStyle(PressableButtonStyle())

                Group {
                    Text("Nudge them outside Tweli · ")
                        .foregroundStyle(Color.twInkTertiary)
                    + Text("Send a text")
                        .foregroundStyle(Color.twAccentInk)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 11)
                .contentShape(Rectangle())
                .onTapGesture {
                    // No recipient: we never store a phone number, so this opens
                    // a blank compose rather than pretending to know how to
                    // reach them. Better than a button that silently does
                    // nothing on a screen about being out of contact.
                    if let url = URL(string: "sms:") { openURL(url) }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 100)
            .padding(.bottom, 32)
        }
    }

    /// Says when, never why. See the note at the top of this file.
    private var explanation: String {
        "Their side has been quiet since \(Self.quietPhrase(for: quietSince)). "
        + "They haven't left the thread — their card is just paused where they left it."
    }

    /// Coarse, and never more precise than the signal deserves.
    static func quietPhrase(for date: Date, now: Date = Date(),
                            calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1:  return "today"
        case 1:     return "yesterday"
        case 2..<7: return "\(days) days ago"
        default:    return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    // MARK: - Pieces

    private var lastCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lastCardHeading)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Color.twInkTertiary)

            HStack(spacing: 11) {
                Text(lastCardEmoji ?? "🌙").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastCardLabel ?? "")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.twInk)
                    if let place = lastCardPlace, !place.isEmpty {
                        Text(place)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.twInkTertiary)
                    }
                }
            }
            .padding(.top, 13)
            // Frozen, not current — the card is dimmed so it never reads as a
            // live update from someone who is not there to send one.
            .opacity(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.twElevated,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.twInk.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var lastCardHeading: String {
        guard let at = lastCardAt else { return "THEIR LAST CARD" }
        return "THEIR LAST CARD · \(Self.quietPhrase(for: at).uppercased())"
    }

    private var waitingNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twWarnInk)
            Text("Anything you send waits for them. They'll see all of it the moment they're back.")
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.twWarn.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.twWarn.opacity(0.28), lineWidth: 0.5)
        }
    }

    /// The thread is intact but dotted — paused, not cut. M4's line stops short
    /// of the far dot; this one reaches it, because they are still there.
    private var quietThread: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 48, y: 88))
                p.addCurve(to: CGPoint(x: 214, y: 40),
                           control1: CGPoint(x: 100, y: 112),
                           control2: CGPoint(x: 158, y: 20))
            }
            .stroke(Color.twWarn.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [3, 8]))

            Circle()
                .fill(TweliGradient.meAvatar)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(couple.currentUser.initials.isEmpty ? "·" : couple.currentUser.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .position(x: 48, y: 88)

            Circle()
                .fill(Color.twWarn.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay {
                    Circle().strokeBorder(Color.twWarn.opacity(0.4), lineWidth: 1.5)
                }
                .overlay {
                    Text(partnerName.prefix(1).uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.twWarnInk)
                }
                .position(x: 214, y: 40)
        }
        .frame(width: 260, height: 120)
    }
}
