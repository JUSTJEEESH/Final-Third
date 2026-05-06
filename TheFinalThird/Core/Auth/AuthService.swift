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
        case signedIn(userID: UUID)
    }

    private(set) var state: AuthState = .unknown
    private let client: SupabaseClient
    private var observerTask: Task<Void, Never>?

    init(client: SupabaseClient = .live) {
        self.client = client
        observerTask = Task { [weak self] in
            await self?.observeAuthChanges()
        }
    }

    deinit { observerTask?.cancel() }

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
        if let user = response.user {
            state = .signedIn(userID: user.id)
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
