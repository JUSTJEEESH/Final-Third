import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    enum Step: Equatable { case landing, email }

    var step: Step = .landing
    var email: String = ""
    var password: String = ""
    var error: String?
    var isWorking: Bool = false

    /// Optional name passed from Apple's identity token through to the
    /// onboarding flow as a presetDisplayName. Stored on the container so
    /// OnboardingViewModel can read it; cleared once consumed.
    var presetDisplayNameFromApple: String?

    private let auth: AuthService
    private let appleCoordinator = AppleSignInCoordinator()
    private let onSignedIn: (UUID) async -> Void

    init(auth: AuthService, onSignedIn: @escaping (UUID) async -> Void = { _ in }) {
        self.auth = auth
        self.onSignedIn = onSignedIn
    }

    func signInWithApple() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let result = try await appleCoordinator.signIn()
            try await auth.signInWithApple(idToken: result.idToken, nonce: result.nonce)
            if let name = result.fullName {
                presetDisplayNameFromApple = [name.givenName, name.familyName]
                    .compactMap { $0 }.joined(separator: " ")
            }
            if case .signedIn(let userID) = auth.state {
                await onSignedIn(userID)
            }
        } catch {
            self.error = "Sign in with Apple failed: \(error.localizedDescription)"
        }
    }

    func signUpWithEmail() async {
        error = nil; isWorking = true; defer { isWorking = false }
        guard isValidEmail(email), password.count >= 8 else {
            error = "Use a real email and a password of at least 8 characters."
            return
        }
        do {
            try await auth.signUp(email: email, password: password)
            switch auth.state {
            case .awaitingEmailConfirmation:
                error = "Check your email — we sent a verification link."
            case .signedIn(let userID):
                await onSignedIn(userID)
            default:
                error = "Couldn't create your account. Try again."
            }
        } catch {
            self.error = "Sign up failed: \(error.localizedDescription)"
        }
    }

    func signInWithEmail() async {
        error = nil; isWorking = true; defer { isWorking = false }
        guard isValidEmail(email), password.count >= 8 else {
            error = "Enter a valid email and a password (8+ characters)."
            return
        }
        do {
            try await auth.signIn(email: email, password: password)
            if case .signedIn(let userID) = auth.state {
                await onSignedIn(userID)
            }
        } catch {
            self.error = "Sign in failed: \(error.localizedDescription)"
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let r = #"^\S+@\S+\.\S+$"#
        return s.range(of: r, options: .regularExpression) != nil
    }
}
