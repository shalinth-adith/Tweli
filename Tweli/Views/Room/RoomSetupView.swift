//
//  RoomSetupView.swift
//  Tweli
//
//  Design 12a — post-login "Join or create" landing.
//

import SwiftUI

struct RoomSetupView: View {
    @EnvironmentObject private var auth: AuthService

    enum Route: Hashable { case create, join }
    @State private var path: [Route] = []

    private var firstName: String {
        auth.displayName.split(separator: " ").first.map(String.init) ?? "there"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                ThreadMotif().frame(width: 70, height: 30).padding(.bottom, 20)

                Text("Welcome,\n\(firstName)")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.primary)
                Text("Start a shared space, or join the one your partner already made.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.top, 8)

                Spacer()

                VStack(spacing: 14) {
                    NavigationLink(value: Route.create) {
                        optionCard(icon: "plus", title: "Create a space",
                                   subtitle: "Start fresh and invite your partner",
                                   filled: true)
                    }.buttonStyle(.plain)

                    NavigationLink(value: Route.join) {
                        optionCard(icon: "arrow.right.to.line", title: "Join a space",
                                   subtitle: "Have an invite link? Paste it here",
                                   filled: false)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .create: CreateSpaceView(onSwitchToJoin: { path = [.join] })
                case .join: JoinSpaceView(onSwitchToCreate: { path = [.create] })
                }
            }
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
                    .foregroundStyle(filled ? .white : .primary)
                Text(subtitle).font(.system(size: 13))
                    .foregroundStyle(filled ? .white.opacity(0.85) : .secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? .white.opacity(0.9) : Color.twInkTertiary)
        }
        .padding(18)
        .background(filled ? Color.twAccent : Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: filled ? Color.twAccent.opacity(0.28) : .black.opacity(0.05),
                radius: filled ? 16 : 4, x: 0, y: filled ? 8 : 1)
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
