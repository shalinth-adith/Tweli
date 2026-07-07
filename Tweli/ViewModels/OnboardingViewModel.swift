//
//  OnboardingViewModel.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Mode: String { case create, join }

    @Published var mode: Mode = .create
    @Published var spaceName = ""
    @Published var myName = ""
    @Published var inviteCode = ""

    var title: String { mode == .create ? "Create Partner Space" : "Join Partner Space" }

    var canContinue: Bool {
        let nameOK = !myName.trimmingCharacters(in: .whitespaces).isEmpty
        switch mode {
        case .create: return nameOK && !spaceName.trimmingCharacters(in: .whitespaces).isEmpty
        case .join: return nameOK && !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}
