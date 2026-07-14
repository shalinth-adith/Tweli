//
//  JoiningView.swift
//  Tweli
//
//  Design 19g/19h — "Tying your thread…". The owner sees this full-screen after
//  creating a space: two avatars joined by a drawn thread, a progress checklist,
//  and a live "waiting for your partner" row. It advances home automatically the
//  moment the partner joins (the space-doc listener fills in `couple.partner`).
//

import SwiftUI

struct JoiningView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.colorScheme) private var scheme

    @State private var drawThread = false
    @State private var showPartnerAvatar = false
    @State private var appear = false
    @State private var progress: CGFloat = 0

    private var spaceTitle: String { couple.coupleSpace?.title ?? "your space" }
    private var youInitial: String { couple.currentUser.initials }
    /// The partner's initial once known, else a soft placeholder heart.
    private var partnerInitial: String { couple.partner?.initials ?? "" }
    private var partnerJoined: Bool { couple.partner != nil }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                Spacer()
                threadHero
                Text(partnerJoined ? "You're connected" : "Tying your thread…")
                    .font(.system(size: 26, weight: .heavy)).kerning(-0.6)
                    .foregroundStyle(.primary)
                    .padding(.top, 26)
                    .opacity(appear ? 1 : 0)
                Text(partnerJoined
                     ? "\(couple.partner?.displayName ?? "Your partner") just joined \(spaceTitle)"
                     : "Setting up \(spaceTitle)")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .opacity(appear ? 1 : 0)

                checklist
                    .padding(.top, 34)

                progressBar
                    .padding(.top, 30)

                Spacer()
                enterButton
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 30)
        }
        .onAppear(perform: start)
        .onChange(of: partnerJoined) { _, joined in
            // Partner arrived — celebrate briefly, then bring the owner home.
            guard joined else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                app.finishOwnerWaiting()
            }
        }
    }

    // MARK: - Hero (two avatars + thread)

    private var threadHero: some View {
        ZStack {
            Circle()
                .fill((scheme == .dark ? Brand.indigoLift : Brand.indigo).opacity(0.14))
                .frame(width: 170, height: 170)
                .scaleEffect(appear ? 1 : 0.6)

            HStack(spacing: 0) {
                AvatarBubble(initial: youInitial, isPartner: false, size: 66)
                    .zIndex(1)

                JoiningThread()
                    .trim(from: 0, to: drawThread ? 1 : 0)
                    .stroke(
                        LinearGradient(colors: [Brand.indigo, Brand.pink], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                    )
                    .frame(width: 96, height: 56)
                    .padding(.horizontal, -6)

                partnerAvatar
                    .zIndex(1)
            }
        }
        .frame(height: 170)
    }

    private var partnerAvatar: some View {
        Group {
            if partnerJoined {
                AvatarBubble(initial: partnerInitial, isPartner: true, size: 66)
            } else {
                // Placeholder until they arrive — a soft dashed ring with a heart.
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(Brand.pink.opacity(0.5))
                    .frame(width: 66, height: 66)
                    .overlay(Image(systemName: "heart.fill").foregroundStyle(Brand.pink.opacity(0.6)))
                    .background(Circle().fill(Brand.pink.opacity(0.08)))
            }
        }
        .scaleEffect(showPartnerAvatar ? 1 : 0.2)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showPartnerAvatar)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: partnerJoined)
    }

    // MARK: - Checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            checkRow("Space created", done: true, delay: 0.8)
            checkRow("Thread secured, end to end", done: true, delay: 1.5)
            checkRow(partnerJoined ? "Your partner joined" : "Waiting for your partner to join…",
                     done: partnerJoined, delay: 2.2, spinning: !partnerJoined)
        }
        .frame(width: 270, alignment: .leading)
    }

    private func checkRow(_ text: String, done: Bool, delay: Double, spinning: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if spinning {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Brand.pink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(progress == 0 ? 0 : 360))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: progress)
                } else {
                    Circle().fill(Brand.green.opacity(0.16)).frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Brand.green)
                }
            }
            .frame(width: 24, height: 24)

            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? .primary : .secondary)
        }
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appear)
    }

    // MARK: - Progress + enter

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Brand.cta(scheme))
                    .frame(width: geo.size.width * (partnerJoined ? 1 : progress))
            }
        }
        .frame(width: 270, height: 4)
        .opacity(appear ? 1 : 0)
    }

    private var enterButton: some View {
        VStack(spacing: 10) {
            if !partnerJoined {
                Button("Enter Tweli now") { app.finishOwnerWaiting() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(partnerJoined
                 ? "Bringing you home…"
                 : "We'll bring you home the moment they arrive.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .opacity(appear ? 1 : 0)
    }

    // MARK: - Animation

    private func start() {
        withAnimation(.easeOut(duration: 0.7)) { appear = true }
        withAnimation(.easeInOut(duration: 1.6).delay(0.7)) { drawThread = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5)) { showPartnerAvatar = true }
        // Nudge the indeterminate progress to ~85% while waiting; completes on join.
        withAnimation(.easeInOut(duration: 3).delay(1)) { progress = 0.85 }
    }
}

/// The curved thread connecting the two avatars on the joining screen.
private struct JoiningThread: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.07, y: h * 0.68))
        p.addCurve(to: CGPoint(x: w * 0.93, y: h * 0.32),
                   control1: CGPoint(x: w * 0.36, y: h * 0.18),
                   control2: CGPoint(x: w * 0.64, y: h * 0.82))
        return p
    }
}
