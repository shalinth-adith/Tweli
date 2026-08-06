//
//  DeleteAccountView.swift
//  Tweli
//
//  Comp W3 "Hold to delete" — the last gate. Nothing here is a tap: the
//  destructive action needs three deliberate seconds, and the way back out is
//  the visually louder of the two buttons.
//
//  Copy differs from the comp on one point, on purpose. The comp promises
//  "gone from every device in 30 days" and "sign back in and everything
//  returns". Deletion is immediate and irreversible — the Firebase Auth user is
//  destroyed, so there is nothing to sign back into. Saying otherwise would be
//  the single worst place in the app to be wrong.
//

import SwiftUI
import AuthenticationServices

struct DeleteAccountView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var letters: OpenWhenLetterService
    @Environment(\.dismiss) private var dismiss

    /// Comp W3's toggle. Default OFF: deletion removes everything you authored
    /// unless you deliberately choose to leave the letters behind.
    @State private var deliverLetters = false

    @State private var holdProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?
    @State private var deleting = false
    @State private var errorText: String?

    private let holdDuration: Double = 3.0

    private var partnerName: String { couple.partner?.displayName ?? "your partner" }
    private var hasPartner: Bool { couple.partner != nil }
    private var sealedCount: Int { letters.letters.filter { $0.isLocked && $0.createdBy == couple.currentUser.id }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Delete forever?")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)

            Text("This is the one thing in Tweli that can't be undone.")
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(Color.twInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            factsCard.padding(.top, 26)

            Spacer(minLength: 24)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.twDangerInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
            }

            Button { dismiss() } label: {
                Text("Never mind — take me back")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.twBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.twInk,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(deleting)

            holdToDelete.padding(.top, 10)

            Text("There is no recovery window. Once this finishes, the account and everything in it is gone.")
                .font(.system(size: 11.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkQuaternary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(deleting)
    }

    // MARK: - What actually happens

    private var factsCard: some View {
        VStack(spacing: 0) {
            fact(icon: "trash.fill", tint: .twDanger,
                 text: "Your moods, letters, reminders and the countdown are erased from every device. This cannot be undone.")

            if hasPartner {
                divider
                fact(icon: "heart.fill", tint: .twAccent2,
                     text: "\(partnerName) keeps everything they wrote, and is told gently that you've left — never a cold “user deleted” screen.")

                divider
                letterToggle
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .tweliCard(radius: 18)
    }

    private func fact(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 32, height: 32)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
                    }
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkChip)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    /// Comp W3's "Deliver my sealed letters first". This is the switch between
    /// the two deletion scopes, so the subtitle says which one is active rather
    /// than describing a count that may be zero.
    private var letterToggle: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.twWarn.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.twWarn)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Leave my letters with \(partnerName)")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.twInk)
                Text(letterToggleSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $deliverLetters)
                .labelsHidden()
                .tint(Color.twSuccess)
                .disabled(deleting)
        }
        .padding(.vertical, 14)
    }

    private var letterToggleSubtitle: String {
        guard deliverLetters else { return "Off — your letters are erased with everything else" }
        return sealedCount > 0
            ? "\(sealedCount) sealed letter\(sealedCount == 1 ? "" : "s") unseal\(sealedCount == 1 ? "s" : "") and stay\(sealedCount == 1 ? "s" : "") theirs"
            : "Your letters stay theirs to keep"
    }

    private var divider: some View {
        Rectangle().fill(Color.twSeparator).frame(height: 1)
    }

    // MARK: - Hold to delete

    private var holdToDelete: some View {
        ZStack {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.twDanger.opacity(0.22))
                    .frame(width: geo.size.width * holdProgress)
            }
            HStack(spacing: 8) {
                if deleting { ProgressView().tint(Color.twDanger) }
                Text(deleting ? "Deleting…" : "Hold to delete · \(Int(holdDuration))s")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.twDanger)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.twDanger.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.twDanger.opacity(0.5), lineWidth: 1)
        }
        .contentShape(Rectangle())
        // A press-and-hold, not a tap: releasing early rewinds, so a stray touch
        // can never delete an account.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !deleting && holdTask == nil { beginHold() } }
                .onEnded { _ in cancelHold() }
        )
        .disabled(deleting)
        .accessibilityLabel("Hold for three seconds to delete your account")
    }

    private func beginHold() {
        errorText = nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        holdTask = Task {
            let step = 0.02
            var elapsed: Double = 0
            while elapsed < holdDuration {
                try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                if Task.isCancelled { return }
                elapsed += step
                holdProgress = CGFloat(min(1, elapsed / holdDuration))
            }
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            await performDelete()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        guard !deleting else { return }
        withAnimation(.easeOut(duration: 0.25)) { holdProgress = 0 }
    }

    private func performDelete() async {
        deleting = true
        do {
            try await app.deleteAccountPermanently(keepLetters: deliverLetters)
            // RootView returns to the entry screen once the signed-in flag
            // clears; there is nothing left here to dismiss.
        } catch {
            // A cancelled Apple sheet is a decision, not a failure.
            let cancelled = (error as? ASAuthorizationError)?.code == .canceled
            errorText = cancelled ? nil : error.localizedDescription
            deleting = false
            withAnimation(.easeOut(duration: 0.25)) { holdProgress = 0 }
        }
        holdTask = nil
    }
}
