//
//  AuthService.swift
//  Tweli
//
//  Sign in with Apple, exchanged for a Firebase Auth session via the native nonce
//  flow. Firebase persists the session in the Keychain automatically; UserDefaults
//  keeps only the display name for offline/first-paint. The persisted "user id" is
//  now the Firebase UID (the canonical membership identity).
//

import Foundation
import Combine
import CryptoKit
import AuthenticationServices

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var appleUserId: String?     // now holds the Firebase UID
    @Published private(set) var displayName: String

    /// Sign-in progress + failure surfaced to SignInView. Errors used to go only
    /// to print(), which made a failed Firebase exchange look like "nothing
    /// happened" on TestFlight builds.
    @Published private(set) var isSigningIn = false
    @Published private(set) var authError: String?

    private let userIdKey = "tweli.auth.appleUserId"
    private let nameKey = "tweli.auth.displayName"
    private let defaults = UserDefaults.standard

    /// The raw nonce generated for the in-flight Sign in with Apple request; sent
    /// (raw) to Firebase alongside Apple's ID token so Firebase can verify the token
    /// was minted for this request. Set in `configure`, consumed in `handleCompletion`.
    private var currentNonce: String?

    /// Wired by AppViewModel to `FirebaseService.signInWithApple`. Kept as a closure
    /// so AuthService needs no Firebase import. Returns the Firebase UID + resolved
    /// display name.
    var exchangeCredential: ((_ idToken: String, _ rawNonce: String,
                              _ fullName: PersonNameComponents?) async throws -> (uid: String, displayName: String))?

    /// Wired by AppViewModel to `FirebaseService.signOut()` so signing out also tears
    /// down the Firebase Auth session.
    var onSignOut: (() -> Void)?

    init() {
        let uid = defaults.string(forKey: userIdKey)
        appleUserId = uid
        displayName = defaults.string(forKey: nameKey) ?? ""
        isSignedIn = uid != nil
    }

    /// Configure the Apple ID request (call from SignInWithAppleButton). Generates a
    /// fresh nonce and sends its SHA-256 hash to Apple.
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the button's completion result. On success, exchange Apple's credential
    /// for a Firebase session, then persist the Firebase UID + display name.
    func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        authError = nil
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = currentNonce else {
                print("[Auth] missing identity token or nonce")
                authError = "Apple didn't return a sign-in token. Please try again."
                return
            }
            let fullName = cred.fullName
            isSigningIn = true
            Task {
                do {
                    guard let exchange = exchangeCredential else {
                        print("[Auth] credential exchange not wired")
                        authError = "Sign-in isn't wired up correctly. Please reinstall the app."
                        isSigningIn = false
                        return
                    }
                    let (uid, name) = try await exchange(idToken, rawNonce, fullName)
                    store(userId: uid, name: name.isEmpty ? fallbackName() : name)
                } catch {
                    print("[Auth] Firebase credential exchange failed: \(error)")
                    authError = "Couldn't finish signing in: \(error.localizedDescription)"
                }
                isSigningIn = false
                currentNonce = nil
            }
        case .failure(let error):
            // A user-cancelled sheet is not an error worth shouting about.
            if (error as? ASAuthorizationError)?.code != .canceled {
                print("[Auth] Sign in with Apple failed: \(error.localizedDescription)")
                authError = "Sign in with Apple failed: \(error.localizedDescription)"
            }
            currentNonce = nil
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
        onSignOut?()
        appleUserId = nil
        defaults.removeObject(forKey: userIdKey)
        isSignedIn = false
    }

#if DEBUG
    /// Dev bypass so the flow is testable without a real Apple/Firebase sign-in.
    /// Excluded from release builds. FirebaseService's own `devSignIn()` (invoked by
    /// AppViewModel on this state change) keeps the service fully offline.
    func devSignIn() {
        store(userId: "dev-\(UUID().uuidString)", name: displayName.isEmpty ? "Shalinth" : displayName)
    }
#endif

    // MARK: - Nonce helpers (standard Firebase Sign in with Apple snippet)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
