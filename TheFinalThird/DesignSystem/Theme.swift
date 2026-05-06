import SwiftUI

/// Applies the global dark-only theme, font, and background.
struct FTTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .background(FTColor.background.ignoresSafeArea())
            .tint(FTColor.gold)
            .foregroundStyle(FTColor.ink)
            .font(FTType.body())
    }
}

extension View {
    func ftTheme() -> some View { modifier(FTTheme()) }
}
