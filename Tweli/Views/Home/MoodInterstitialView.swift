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
//  NOTE — the two directions no longer differ. KEEP used to leave the mood as
//  the prominent card on Home while DISMISS collapsed it to a one-line strip;
//  the strip is gone (L3/N3 rest on the full card), so both now mean "seen".
//  The stamps still read KEEP and DISMISS, which is a promise this screen can
//  no longer keep — worth resolving, either by simplifying to a neutral
//  fling-to-close or by giving KEEP something real to do.
//

import SwiftUI
import UIKit

struct MoodInterstitialView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Right swipe. Acknowledges the mood — see the note at the top of the file
    /// for why this is no longer distinguishable from `onDismiss`.
    var onKeep: () -> Void
    /// Left swipe / × / scrim tap. Also acknowledges the mood.
    var onDismiss: () -> Void

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
                .onTapGesture { onDismiss() }

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
        .overlay(alignment: .topLeading) { moodsStamp }
        .overlay(alignment: .topTrailing) { dismissStamp }
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
            // Swipe-direction hints (designs 22a/b) — no action buttons; the card
            // is driven entirely by the drag.
            HStack {
                Label("Swipe left", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Label("Swipe right", systemImage: "chevron.right")
                    .environment(\.layoutDirection, .rightToLeft)   // icon trails the text
            }
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Color.twInkTertiary)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .semibold))
                Text("Only you can see how you respond")
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

    // MARK: - Drag stamps (appear as you pull)

    private var moodsStamp: some View {
        stamp(text: "KEEP", color: .twSuccess, rotation: -15, systemImage: "heart.fill")
            .opacity(stampOpacity(forRightward: true))
            .padding(.top, 20).padding(.leading, 32)
    }

    private var dismissStamp: some View {
        stamp(text: "DISMISS", color: Color(UIColor.systemGray), rotation: 15, systemImage: "xmark")
            .opacity(stampOpacity(forRightward: false))
            .padding(.top, 20).padding(.trailing, 32)
    }

    private func stamp(text: String, color: Color, rotation: Double, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.system(size: 13, weight: .black))
            Text(text)
                .font(.system(size: 17, weight: .black))
                .kerning(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12).padding(.vertical, 5)
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(color, lineWidth: 3))
        .rotationEffect(.degrees(rotation))
        .allowsHitTesting(false)
    }

    private func stampOpacity(forRightward: Bool) -> Double {
        let d = drag.width
        let active = forRightward ? d : -d
        return Double(min(max(active / threshold, 0), 1))
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button { onDismiss() } label: {
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
                if value.translation.width > threshold {
                    fling(keep: true)
                } else if value.translation.width < -threshold {
                    fling(keep: false)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func fling(keep: Bool) {
        let sign: CGFloat = keep ? 1 : -1
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: sign * 700, height: 60)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if keep { onKeep() } else { onDismiss() }
        }
    }
}
