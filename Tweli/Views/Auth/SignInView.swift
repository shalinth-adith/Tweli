//
//  SignInView.swift
//  Tweli
//
//  First screen: Sign in with Apple (iOS-only). On success AuthService stores
//  the Apple user id + name and the app advances to room setup.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 10) {
                dot(.twAccent2)
                Image(systemName: "heart.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.twAccent)
                    .scaleEffect(appear ? 1 : 0.4)
                dot(Color(red: 1, green: 0.42, blue: 0.54))
            }
            .opacity(appear ? 1 : 0)
            .padding(.bottom, 30)

            VStack(spacing: 10) {
                Text("Tweli").font(.system(size: 38, weight: .heavy)).foregroundStyle(.primary)
                Text("Two hearts. One space.\nAny distance.")
                    .font(.system(size: 16)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
            .opacity(appear ? 1 : 0)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    auth.configure(request)
                } onCompletion: { result in
                    auth.handleCompletion(result)
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if auth.isSigningIn {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Finishing sign-in…").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error = auth.authError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                }

                Text("We use your Apple account so only you two share this space.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

#if DEBUG
                Button("Continue in dev mode") { auth.devSignIn() }
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, 6)
#endif
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.twBackground.ignoresSafeArea())
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true } }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 13, height: 13)
    }
}
