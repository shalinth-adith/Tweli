//
//  SplashView.swift
//  Tweli
//

import SwiftUI

struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.twBackground.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(TweliGradient.hero)
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.twAccent.opacity(0.4), radius: 18, x: 0, y: 10)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)

                VStack(spacing: 6) {
                    Text("Tweli")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Remember things together")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
        }
    }
}

#Preview { SplashView() }
