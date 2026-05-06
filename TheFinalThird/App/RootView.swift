import SwiftUI

/// Routes between auth and the main tab bar based on `AuthService.state`.
struct RootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        switch container.auth.state {
        case .unknown:
            SplashView()
        case .signedOut, .awaitingEmailConfirmation:
            AuthView()
        case .signedIn:
            if container.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
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

