import AuthenticationServices
import Foundation
import Supabase

/// Authenticates the user via Sign in with Apple (primary) or email/password.
/// Owns the auth state and surfaces it as an AsyncStream of `AuthState`.
@MainActor
@Observable
final class AuthService {
    enum AuthState: Sendable, Equatable {
        case unknown
        case signedOut
        case awaitingEmailConfirmation
        case signedIn(userID: UUID)
    }

    private(set) var state: AuthState = .unknown
    private let client: SupabaseClient

    init(client: SupabaseClient = .live) {
        self.client = client
        // The observer task captures self weakly and ends naturally when
        // self deallocates (the for-await body becomes a no-op via `self?`
        // and the SDK's stream still completes when the client tears down).
        // AuthService lives for the app's lifetime in AppContainer, so we
        // don't need a deinit cancel.
        Task { [weak self] in await self?.observeAuthChanges() }
    }

    func bootstrap() async {
        do {
            let session = try await client.auth.session
            state = .signedIn(userID: session.user.id)
        } catch {
            state = .signedOut
        }
    }

    // MARK: Sign in with Apple

    /// Exchanges an Apple identity token for a Supabase session.
    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        state = .signedIn(userID: session.user.id)
    }

    // MARK: Email + password (secondary)

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        state = .signedIn(userID: session.user.id)
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        // If Supabase has email confirmation enabled, response.session is nil
        // and the user can't make authenticated calls until they click the
        // verification link. Don't claim signed in — we'd otherwise jump
        // into the main tab and immediately fail every API call.
        if response.session != nil {
            state = .signedIn(userID: response.user.id)
        } else {
            state = .awaitingEmailConfirmation
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut
    }

    // MARK: Internal

    private func observeAuthChanges() async {
        for await change in client.auth.authStateChanges {
            switch change.event {
            case .signedIn, .tokenRefreshed, .userUpdated:
                if let user = change.session?.user {
                    state = .signedIn(userID: user.id)
                }
            case .signedOut, .userDeleted:
                state = .signedOut
            default:
                break
            }
        }
    }
}
