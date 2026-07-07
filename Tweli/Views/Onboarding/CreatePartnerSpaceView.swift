//
//  CreatePartnerSpaceView.swift
//  Tweli
//

import SwiftUI

struct CreatePartnerSpaceView: View {
    let mode: OnboardingViewModel.Mode

    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        Form {
            Section("Your name") {
                TextField("e.g. Shalinth", text: $vm.myName)
            }

            if vm.mode == .create {
                Section("Couple space name") {
                    TextField("e.g. Shalinth & Anaya", text: $vm.spaceName)
                }
                Section {
                    Label("Invite your partner", systemImage: "qrcode")
                        .foregroundStyle(.secondary)
                    Text("Share an invite code, link, or QR after you create the space.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            } else {
                Section("Invite code") {
                    TextField("Enter partner's code", text: $vm.inviteCode)
                        .textInputAutocapitalization(.characters)
                }
            }

            Section {
                PrimaryButton(title: vm.mode == .create ? "Create Space" : "Join Space",
                              systemImage: "heart.fill") {
                    connect()
                }
                .disabled(!vm.canContinue)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(vm.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.mode = mode
            app.requestNotificationPermission()
        }
    }

    private func connect() {
        switch vm.mode {
        case .create:
            couple.createSpace(title: vm.spaceName, myName: vm.myName)
        case .join:
            Task { await couple.joinSpace(code: vm.inviteCode, myName: vm.myName) }
        }
    }
}
