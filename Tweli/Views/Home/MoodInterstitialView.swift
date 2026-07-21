//
//  MoodInterstitialView.swift
//  Tweli
//
//  The "new mood" interstitial (designs 22a/b): a warm, Tinder-style card that
//  greets you on open when your partner has posted a new mood since you last
//  looked. Drag it —
//    • right  → flings off and opens the Moods tab
//    • left   → flings off and stays on Home (the mood rests as a card)
//  Below the threshold it springs back. Tap the × or the scrim to skip.
//
//  It is SILENT: nothing is sent to the partner, no receipt, no record of which
//  way you swiped. The scrim fades and Home brightens as you drag.
//

import SwiftUI
import UIKit

struct MoodInterstitialView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Right swipe / "Moods" — open the Moods tab.
    var onOpenMoods: () -> Void
    /// Left swipe / × / scrim tap — dismiss to Home.
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
        .background(Color(UIColor.secondarySystemGroupedBackground))   // white / #1C1C1E
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
                .fill(LinearGradient(colors: [Color(red: 0.482, green: 0.475, blue: 1.0), .twAccent2],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 76, height: 76)
                .overlay(Text(partnerInitials).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: Color.twAccent2.opacity(0.34), radius: 13, x: 0, y: 10)

            Text("\(partnerName) feels")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)

            Text(mood.mood.label)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 3)

            if let note = mood.note, !note.isEmpty {
                Text("“\(note)”")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 20) {
            footerAction(icon: "chevron.left", label: "Home", tint: Color(UIColor.systemGray)) { onDismiss() }

            VStack(spacing: 0) {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
                Text("Private").font(.system(size: 11, weight: .semibold)).padding(.top, 4)
            }
            .foregroundStyle(.tertiary)

            footerAction(icon: "face.smiling", label: "Moods", tint: .twSuccess) { onOpenMoods() }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(UIColor.separator).opacity(0.5)).frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func footerAction(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(Circle())
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drag stamps (appear as you pull)

    private var moodsStamp: some View {
        stamp(text: "MOODS", color: .twSuccess, rotation: -15)
            .opacity(stampOpacity(forRightward: true))
            .padding(.top, 20).padding(.leading, 32)
    }

    private var dismissStamp: some View {
        stamp(text: "DISMISS", color: Color(UIColor.systemGray), rotation: 15)
            .opacity(stampOpacity(forRightward: false))
            .padding(.top, 20).padding(.trailing, 32)
    }

    private func stamp(text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .black))
            .kerning(1)
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
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(UIColor.tertiarySystemFill))
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
                    fling(openMoods: true)
                } else if value.translation.width < -threshold {
                    fling(openMoods: false)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func fling(openMoods: Bool) {
        let sign: CGFloat = openMoods ? 1 : -1
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: sign * 700, height: 60)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if openMoods { onOpenMoods() } else { onDismiss() }
        }
    }
}
