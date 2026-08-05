//
//  RoomSetupView.swift
//  Tweli
//
//  Comp A4 — "Your space, for two". One of you starts, the other joins.
//

import SwiftUI

struct RoomSetupView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var app: AppViewModel

    enum Route: Hashable { case create, join }
    @State private var path: [Route] = []

    private var firstName: String {
        // The user's own name (edited on "About you") is the source of truth;
        // fall back to the Apple name only if they never set one.
        let name = couple.currentUser.displayName.isEmpty ? auth.displayName : couple.currentUser.displayName
        return name.split(separator: " ").first.map(String.init) ?? "there"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                ThreadMotif().frame(width: 70, height: 30).padding(.bottom, 22)

                Text("Step 2 of 3")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.twAccentInk)

                Text(firstName == "there" ? "Your space,\nfor two" : "\(firstName), your space\nfor two")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.7)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 8)

                Text("A space holds everything you share. Only the two of you can ever see inside.")
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: 24)

                VStack(spacing: 14) {
                    NavigationLink(value: Route.create) {
                        optionCard(icon: "plus", title: "Start our space",
                                   subtitle: "Create it and send your partner a private invite code.",
                                   filled: true)
                    }.buttonStyle(.plain)

                    NavigationLink(value: Route.join) {
                        optionCard(icon: "arrow.right.to.line", title: "Join with a code",
                                   subtitle: "Your partner already started — enter the code they sent you.",
                                   filled: false)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.twBackground.ignoresSafeArea())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .create: CreateSpaceView(onSwitchToJoin: { path = [.join] })
                case .join: JoinSpaceView(onSwitchToCreate: { path = [.create] })
                }
            }
        }
        // An invite link (tapped or pasted) routes straight to Join a space, where
        // the code pre-fills. Handles the link arriving before OR after this screen.
        .onAppear { if app.pendingJoinCode != nil, path.isEmpty { path = [.join] } }
        .onChange(of: app.pendingJoinCode) { _, code in
            if code != nil, path.last != .join { path = [.join] }
        }
    }

    private func optionCard(icon: String, title: String, subtitle: String, filled: Bool) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(filled ? Color.white.opacity(0.22) : Color.twAccent2.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(filled ? .white : Color.twAccent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(filled ? Color.white : Color.twInk)
                Text(subtitle).font(.system(size: 13))
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(filled ? Color.white.opacity(0.85) : Color.twInkSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? .white.opacity(0.9) : Color.twInkTertiary)
        }
        .padding(18)
        .background(filled ? Color.twAccent : Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if !filled {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.twHairline, lineWidth: 1)
            }
        }
        // Comp: only the primary card glows; the secondary sits flat.
        .shadow(color: filled ? Color.twAccent.opacity(0.35) : .clear, radius: filled ? 15 : 0)
    }
}

/// The two-dots-and-thread motif from the app icon.
struct ThreadMotif: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.16, y: h * 0.75))
                    p.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.25),
                               control1: CGPoint(x: w * 0.36, y: h * 0.1),
                               control2: CGPoint(x: w * 0.64, y: h * 0.9))
                }
                .stroke(LinearGradient(colors: [.twAccent2, .twAccent],
                                       startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle().fill(Color.twAccent2)
                    .frame(width: h * 0.35, height: h * 0.35)
                    .position(x: w * 0.16, y: h * 0.75)
                Circle().fill(Color.twAccent)
                    .frame(width: h * 0.35, height: h * 0.35)
                    .position(x: w * 0.84, y: h * 0.25)
            }
        }
    }
}
