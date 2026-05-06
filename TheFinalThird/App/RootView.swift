import SwiftUI

/// Routes between auth and the main tab bar based on `AuthService.state`.
struct RootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        switch container.auth.state {
        case .unknown:
            SplashView()
        case .signedOut:
            // Auth feature lives in Features/Auth — the placeholder lets the
            // app compile while that feature is in flight.
            AuthPlaceholderView()
        case .signedIn:
            MainTabView()
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            VStack(spacing: FTSpace.lg) {
                ProgressView().tint(FTColor.gold)
                Text("Pouring a drink…")
                    .font(FTType.body(14))
                    .foregroundStyle(FTColor.inkMuted)
            }
        }
    }
}

private struct AuthPlaceholderView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: FTSpace.xl) {
            Spacer()
            Text("The Final Third")
                .font(FTType.display(40))
                .foregroundStyle(FTColor.gold)
            Text("A digital third place.")
                .font(FTType.body(16))
                .foregroundStyle(FTColor.inkMuted)
            Spacer()
            FTButton(title: "Sign in with Apple", style: .gold) {
                Task {
                    let coordinator = AppleSignInCoordinator()
                    do {
                        let result = try await coordinator.signIn()
                        try await container.auth.signInWithApple(
                            idToken: result.idToken, nonce: result.nonce
                        )
                    } catch {
                        // surfaced by the auth feature; placeholder swallows
                    }
                }
            }
            .padding(.horizontal, FTSpace.xl)
            Spacer().frame(height: FTSpace.xl)
        }
    }
}
