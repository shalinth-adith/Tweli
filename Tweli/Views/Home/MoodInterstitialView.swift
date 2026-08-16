//
//  MoodInterstitialView.swift
//  Tweli
//
//  The "new mood" interstitial (designs 22a/b): a warm, Tinder-style card that
//  greets you on open when your partner has posted a new mood since you last
//  looked. Drag it either way to fling it off; below the threshold it springs
//  back. Tap the × or the scrim to dismiss.
//
//  It is SILENT: nothing is sent to the partner, no receipt, no record of which
//  way you swiped. The scrim fades and Home brightens as you drag.
//
//  The two directions do NOT differ, and the screen no longer pretends they do.
//  KEEP used to leave the mood as the prominent card on Home while DISMISS
//  collapsed it to a one-line strip; the strip is gone (L3/N3 rest on the full
//  card), so there is nothing left for the choice to decide. The stamps went
//  with it rather than staying on as decoration — a card that offers you two
//  labelled outcomes and then delivers the same one either way teaches people to
//  distrust the rest of the app's buttons.
//
//  What remains is the part that was always doing the work: a card you fling
//  away in whichever direction your thumb happens to be going.
//

import SwiftUI
import UIKit

struct MoodInterstitialView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Swiped away, tapped past, or closed — all the same thing: the mood has
    /// been seen, so the interstitial won't raise again until a newer one lands.
    var onSeen: () -> Void

    @State private var drag: CGSize = .zero
    @State private var appeared = false

    /// Past this horizontal travel, releasing commits the swipe.
    private let threshold: CGFloat = 110

    var body: some View {
        ZStack {
            // Scrim — fades toward transparent as the card is dragged aside, so
            // Home brightens underneath ("stepping in").
            Color.black
                .opacity(scrimOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onSeen() }

            card
                .offset(x: drag.width, y: drag.height * 0.12)
                .rotationEffect(.degrees(Double(drag.width) / 18))
                .scaleEffect(appeared ? 1 : 0.9)
                .gesture(dragGesture)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { appeared = true } }
    }

    // MARK: - Scrim

    private var scrimOpacity: Double {
        let progress = min(abs(drag.width) / 320, 1)
        return 0.45 * (1 - progress)
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            header
            content
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: 340)
        .background(Color.twElevated)   // white / #1C1C1E
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) { closeButton }
        .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 26)
        .padding(.horizontal, 22)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.twAccent)
                .frame(width: 9, height: 9)
            Text("New mood · \(mood.relativeLabel)")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .kerning(0.7)
                .foregroundStyle(Color.twAccent)
            Spacer()
        }
        .padding(.trailing, 34)   // clear the × button
        .padding(.bottom, 16)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(TweliGradient.partnerAvatar)
                .frame(width: 76, height: 76)
                .overlay(Text(partnerInitials).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: Color.twAccent2.opacity(0.34), radius: 13, x: 0, y: 10)

            Text("\(partnerName) feels")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(Color.twInkTertiary)
                .padding(.top, 16)

            Text(mood.displayLabel)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 3)

            if let note = mood.note, !note.isEmpty {
                Text("“\(note)”")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            // One hint, not two. The comp put "Swipe left" and "Swipe right" at
            // opposite ends because the two directions used to mean different
            // things; presenting them as a pair now would imply a choice that
            // isn't there. The card is still driven entirely by the drag — there
            // are no action buttons.
            HStack(spacing: 7) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .black))
                Text("Swipe either way")
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .black))
            }
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Color.twInkTertiary)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .semibold))
                // Was "how you respond", which described a choice being recorded.
                // Nothing is recorded and nothing is sent — the honest version of
                // that reassurance is that they are not told you looked.
                Text("\(partnerName) isn't told you saw this")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color(UIColor.quaternaryLabel))
        }
        .padding(.top, 15)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.twSeparator.opacity(0.5)).frame(height: 1)
        }
        .padding(.top, 4)
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button { onSeen() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.twInkSecondary)
                .frame(width: 30, height: 30)
                .background(Color.twInkTertiary.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 14).padding(.trailing, 14 + 22)   // +card horizontal inset
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                // Either direction closes it. Below the threshold it springs
                // back, which is the only distinction the gesture still makes.
                if abs(value.translation.width) > threshold {
                    fling(towards: value.translation.width > 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    /// Continue the card off-screen the way it was already travelling.
    private func fling(towards sign: CGFloat) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: sign * 700, height: 60)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onSeen() }
    }
}
