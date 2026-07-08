//
//  AuthService.swift
//  Tweli
//
//  Sign in with Apple. Persists the Apple user id + display name so the user
//  stays signed in across launches. (MVP uses UserDefaults; move the user id to
//  the Keychain for production.)
//

import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var appleUserId: String?
    @Published private(set) var displayName: String

    private let userIdKey = "tweli.auth.appleUserId"
    private let nameKey = "tweli.auth.displayName"
    private let defaults = UserDefaults.standard

    init() {
        let uid = defaults.string(forKey: userIdKey)
        appleUserId = uid
        displayName = defaults.string(forKey: nameKey) ?? ""
        isSignedIn = uid != nil
    }

    /// Configure the Apple ID request (call from SignInWithAppleButton).
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handle the button's completion result.
    func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            // fullName / email are only provided on the FIRST authorization — persist them.
            let given = cred.fullName?.givenName
            let family = cred.fullName?.familyName
            let name = [given, family].compactMap { $0 }.joined(separator: " ")
            store(userId: cred.user, name: name.isEmpty ? fallbackName() : name)
        case .failure(let error):
            print("[Auth] Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    private func fallbackName() -> String { displayName.isEmpty ? "You" : displayName }

    private func store(userId: String, name: String) {
        appleUserId = userId
        displayName = name
        defaults.set(userId, forKey: userIdKey)
        defaults.set(name, forKey: nameKey)
        isSignedIn = true
    }

    func signOut() {
        appleUserId = nil
        defaults.removeObject(forKey: userIdKey)
        isSignedIn = false
    }

#if DEBUG
    /// Dev bypass so the flow is testable without an iCloud-signed-in simulator.
    /// Excluded from release builds (see Placeholder & Auth-bypass conventions).
    func devSignIn() {
        store(userId: "dev-\(UUID().uuidString)", name: displayName.isEmpty ? "Shalinth" : displayName)
    }
#endif
}
