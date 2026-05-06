import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    enum Step: Equatable { case landing, email, profileSetup }

    var step: Step = .landing
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var handle: String = ""
    var city: String = ""
    var isHondurasLocal: Bool = false
    var error: String?
    var isWorking: Bool = false

    private let auth: AuthService
    private let profiles: ProfileRepository
    private let appleCoordinator = AppleSignInCoordinator()

    init(auth: AuthService, profiles: ProfileRepository = LiveProfileRepository()) {
        self.auth = auth
        self.profiles = profiles
    }

    func signInWithApple() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let result = try await appleCoordinator.signIn()
            try await auth.signInWithApple(idToken: result.idToken, nonce: result.nonce)
            if let name = result.fullName {
                displayName = [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
            }
            step = .profileSetup
        } catch {
            self.error = error.localizedDescription
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
        } catch {
            self.error = "Couldn't sign in. Check your details."
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
            // If Supabase has email confirmation enabled, auth.state moves to
            // .awaitingEmailConfirmation. Surface that to the user instead of
            // jumping into profile setup with no session.
            switch auth.state {
            case .awaitingEmailConfirmation:
                error = "Check your email — we sent a verification link."
            case .signedIn:
                step = .profileSetup
            default:
                error = "Couldn't create your account. Try again."
            }
        } catch {
            self.error = "Couldn't create your account. Try again."
        }
    }

    func saveProfile() async {
        error = nil; isWorking = true; defer { isWorking = false }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "We need something to call you."
            return
        }
        guard case .signedIn(let userID) = auth.state else {
            error = "Not signed in."
            return
        }
        let profile = Profile(
            id: userID,
            email: email.isEmpty ? nil : email,
            displayName: displayName,
            handle: handle.isEmpty ? nil : handle,
            avatarURL: nil,
            bio: nil,
            city: city.isEmpty ? nil : city,
            isHondurasLocal: isHondurasLocal,
            isPremium: false,
            audioTheme: nil,
            voiceEnabled: false,
            ghostModeDefault: false,
            notificationPrefs: .default,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            timezone: TimeZone.current.identifier,
            createdAt: .now
        )
        do {
            try await profiles.upsert(profile)
            step = .landing
        } catch {
            self.error = "Couldn't save your profile. Try again."
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let r = #"^\S+@\S+\.\S+$"#
        return s.range(of: r, options: .regularExpression) != nil
    }
}
