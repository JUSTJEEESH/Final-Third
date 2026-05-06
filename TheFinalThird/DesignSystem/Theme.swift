import SwiftUI

/// Applies the global dark-only theme, font, and background — including
/// a very subtle leather grain over the base color so flat surfaces have
/// some warmth instead of reading as pure black.
struct FTTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .background(FTAppBackground().ignoresSafeArea())
            .tint(FTColor.gold)
            .foregroundStyle(FTColor.ink)
            .font(FTType.body())
    }
}

extension View {
    func ftTheme() -> some View { modifier(FTTheme()) }
}

/// Global app background. Base color + faint leather grain + soft warm
/// vignette from the top — gives the whole app the feel of a low-lit room
/// without ever being bright.
struct FTAppBackground: View {
    var body: some View {
        ZStack {
            FTColor.background
            TexturePanel(texture: .leather, opacity: 0.08)
            // Warm overhead "lamp" glow.
            RadialGradient(
                colors: [
                    FTColor.gold.opacity(0.06),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 380
            )
        }
    }
}

/// Charred-wood "floor" for the tab bar. Texture tiles at a smaller
/// size here so the wood grain reads as planks rather than a giant
/// stretched panel.
struct FTFloorBackground: View {
    var body: some View {
        ZStack {
            FTColor.charredWood
            TexturePanel(texture: .charredWood, opacity: 0.85, tileSize: 160)
            // Lift the top edge a touch so the floor reads as separate
            // from the room above it.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.4),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .clipped()
    }
}
