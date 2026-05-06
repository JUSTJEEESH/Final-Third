import SwiftUI

@main
struct TheFinalThirdApp: App {
    @State private var container = AppContainer()
    @State private var router = DeepLinkRouter()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(router)
                .ftTheme()
                .task { await container.bootstrap() }
                .onOpenURL { router.handle(url: $0) }
        }
    }
}
