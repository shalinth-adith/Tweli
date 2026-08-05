//
//  AddOpenWhenLetterView.swift
//  Tweli
//
//  Comp L12 / N12 / E4 — the letter composer, and what happens when sealing
//  fails. The composer itself is deliberately plain: a title, the body, and the
//  seal date. The whole design of this screen is the failure case — "the draft
//  is sacred", so a failed seal never loses a word and never closes the sheet.
//

import SwiftUI

struct AddOpenWhenLetterView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: OpenWhenLetterService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddOpenWhenLetterViewModel()

    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        composerCard
                        sealSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 140)
                }
                .background(Color.twBackground.ignoresSafeArea())
                .scrollDismissesKeyboard(.interactively)

                if failed {
                    FailureToast(
                        title: "Couldn't seal your letter",
                        message: "No connection. Every word is saved right here.",
                        onRetry: { withAnimation { failed = false }; save() },
                        onDismiss: { withAnimation { failed = false } }
                    )
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("New letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.twAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Seal") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(vm.canSave ? Color.twAccent : Color.twInkQuaternary)
                        .disabled(!vm.canSave)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: failed)
        }
    }

    // MARK: - Composer

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Open when…", text: $vm.title, axis: .vertical)
                .font(.system(size: 19, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Color.twInk)
                .lineLimit(1...2)

            TextField("Say the thing you'd want them to read at exactly that moment…",
                      text: $vm.message, axis: .vertical)
                .font(.system(size: 16))
                .lineSpacing(6)
                .foregroundStyle(Color.twInk)
                .lineLimit(6...20)
                .padding(.top, 14)

            if vm.useUnlockDate {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                    Text("Seals until \(vm.unlockDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.twSeparator).frame(height: 1)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: 16)
    }

    private var sealSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $vm.useUnlockDate.animation()) {
                Text("Lock until a date & time")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInk)
            }
            .tint(Color.twAccent)
            .padding(.vertical, 12)

            if vm.useUnlockDate {
                Rectangle().fill(Color.twSeparator).frame(height: 1)
                DatePicker("Unlocks on", selection: $vm.unlockDate,
                           in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                    .tint(Color.twAccent)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .tweliCard(radius: 18)
        .padding(.top, 16)
        .overlay(alignment: .bottom) {
            if vm.useUnlockDate {
                Text("The letter stays sealed until this moment, then opens on its own.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .offset(y: 34)
            }
        }
    }

    // MARK: - Save

    private func save() {
        // No space means nothing to write into — surface it rather than
        // silently dropping the letter (comp E4's whole point).
        guard let spaceId = app.coupleSpaceService.coupleSpace?.id else {
            withAnimation { failed = true }
            return
        }
        service.add(vm.build(createdBy: app.currentUser.id, coupleSpaceId: spaceId))
        dismiss()
    }
}
