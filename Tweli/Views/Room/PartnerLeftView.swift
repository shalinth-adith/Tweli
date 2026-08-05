//
//  PartnerLeftView.swift
//  Tweli
//
//  Comp E6 — "the hardest screen — gentle, no guilt". Your dot is still lit;
//  theirs has gone grey. Nothing here blames anyone, and the primary action is
//  an open door rather than a goodbye.
//
//  Raised by AppViewModel.partnerLeftName, which is set when the space-doc
//  listener sees the other member remove themselves (FirebaseService.announceLeave).
//

import SwiftUI

struct PartnerLeftView: View {
    /// The name of whoever left, so the headline can say who.
    let partnerName: String
    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                avatars
                Text("\(partnerName) left the space")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)

                Text("Everything you wrote together is safe for 30 days. You can invite \(partnerName) back anytime, or begin something new.")
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Button { app.startFreshAfterPartnerLeft() } label: {
                    Text("Send a new invite")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.twAccentInk,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.twAccent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 32)

                Button { app.startFreshAfterPartnerLeft() } label: {
                    Text("Start fresh")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.twInkSecondary)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 34)
        }
    }

    /// Yours still lit, theirs gone quiet — the thread between them is gone.
    private var avatars: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(TweliGradient.meAvatar)
                .frame(width: 56, height: 56)
                .overlay {
                    Text(couple.currentUser.initials.isEmpty ? "·" : couple.currentUser.initials)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .zIndex(1)

            // The broken thread: a short dashed run going nowhere.
            Rectangle()
                .fill(Color.twInkTertiary.opacity(0.3))
                .frame(width: 44, height: 1.5)
                .mask {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle().frame(width: 5)
                        }
                    }
                }

            Circle()
                .fill(Color.twInkTertiary.opacity(0.16))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(partnerName.prefix(1).uppercased())
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.twInkQuaternary)
                }
        }
    }
}
