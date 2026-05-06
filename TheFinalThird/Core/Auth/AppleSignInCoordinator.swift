import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Drives Sign in with Apple. Generates and stores the nonce, exposes the
/// raw nonce for Supabase id-token exchange.
@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerPresentationContextProviding {
    struct Result: Sendable {
        let idToken: String
        let nonce: String
        let fullName: PersonNameComponents?
        let email: String?
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var currentNonce: String?

    func signIn() async throws -> Result {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = Delegate { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8),
                      let nonce = self.currentNonce else {
                    self.continuation?.resume(throwing: AppError.unknown("Apple credential malformed"))
                    return
                }
                self.continuation?.resume(returning: Result(
                    idToken: token,
                    nonce: nonce,
                    fullName: credential.fullName,
                    email: credential.email
                ))
            case .failure(let error):
                self.continuation?.resume(throwing: error)
            }
        }
        controller.delegate = delegate
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Result, Error>) in
            self.continuation = cont
            objc_setAssociatedObject(controller, &Self.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    private static var delegateKey: UInt8 = 0

    private final class Delegate: NSObject, ASAuthorizationControllerDelegate {
        let handler: (Swift.Result<ASAuthorization, Error>) -> Void
        init(handler: @escaping (Swift.Result<ASAuthorization, Error>) -> Void) {
            self.handler = handler
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) { handler(.success(authorization)) }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) { handler(.failure(error)) }
    }

    // MARK: Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let chars: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < chars.count {
                result.append(chars[Int(random) % chars.count])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
