import SwiftUI

struct FTCard<Content: View>: View {
    var padding: CGFloat = FTSpace.lg
    var elevated: Bool = false
    var texture: FTTexture? = .leather
    var textureIntensity: Double = 0.22
    /// Zoom into the texture image for finer grain detail. >1 shows a
    /// smaller crop at higher resolution. 1.4 looks right for leather
    /// on a card-sized surface.
    var textureZoom: CGFloat = 1.4
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                ZStack {
                    (elevated ? FTColor.surfaceHi : FTColor.surface)
                    if let texture {
                        TexturePanel(texture: texture,
                                     opacity: textureIntensity,
                                     zoom: textureZoom)
                    }
                    // Soft top highlight — light catching the leather edge.
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.05), location: 0),
                            .init(color: .clear, location: 0.5),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                FTColor.divider,
                                FTColor.divider.opacity(0.25),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: FTStroke.hairline
                    )
            )
            .shadow(color: .black.opacity(elevated ? 0.55 : 0.30),
                    radius: elevated ? 14 : 6,
                    x: 0,
                    y: elevated ? 8 : 3)
    }
}

struct GoldDivider: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    .clear,
                    FTColor.gold.opacity(0.7),
                    FTColor.goldHi.opacity(0.4),
                    .clear,
                ],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 1)
    }
}
