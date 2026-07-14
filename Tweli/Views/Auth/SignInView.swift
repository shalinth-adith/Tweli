//
//  SignInView.swift
//  Tweli
//
//  Design 19a/19b — Sign in. Brand backdrop, animated thread logo, and the
//  Sign in with Apple flow (the only provider for launch). Google / email in
//  the comp are intentionally deferred until their backends exist.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                Spacer()
                header
                Spacer()
                Spacer()
                actions
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { appear = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            ThreadLogo(size: 56)
                .padding(22)
                .background(logoTile)
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)

            Text("TWELI")
                .font(.system(size: 15, weight: .semibold))
                .kerning(7)
                .foregroundStyle(.primary)
                .padding(.top, 22)
                .opacity(appear ? 1 : 0)

            Text("Two of you.\nOne space.")
                .font(.system(size: 32, weight: .heavy))
                .kerning(-0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.top, 16)
                .opacity(appear ? 1 : 0)

            Text("Reminders, dates, moods and letters — shared with the only person who matters.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 290)
                .padding(.top, 12)
                .opacity(appear ? 1 : 0)
        }
    }

    private var logoTile: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(scheme == .dark
                  ? LinearGradient(colors: [Color(hex: "1E1830"), Color(hex: "0D0A16")], startPoint: .topLeading, endPoint: .bottomTrailing)
                  : LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F1F0FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 88, height: 88)
            .shadow(color: Brand.indigo.opacity(scheme == .dark ? 0.4 : 0.18), radius: 20, y: 12)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                auth.configure(request)
            } onCompletion: { result in
                auth.handleCompletion(result)
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .disabled(auth.isSigningIn)

            if auth.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finishing sign-in…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else if let error = auth.authError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Brand.pink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text("By continuing you agree to our Terms & Privacy.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

#if DEBUG
            Button("Continue in dev mode") { auth.devSignIn() }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
#endif
        }
        .opacity(appear ? 1 : 0)
    }
}
