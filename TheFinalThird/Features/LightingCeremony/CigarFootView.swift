import SwiftUI

/// A stylized cigar drawn with shapes, with an animated foot ember that
/// blooms in once ignition completes. Sits beside the flame in the
/// ceremony so the viewer sees the actual moment of lighting.
struct CigarFootView: View {
    /// 0…1 — drives ember bloom + size at the foot.
    var ignitedAmount: Double = 0
    var bodyLength: CGFloat = 220
    var bodyDiameter: CGFloat = 26

    var body: some View {
        ZStack(alignment: .leading) {
            // Cigar body — long capsule with subtle wrapper texture
            Capsule()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x3A2515), location: 0.0),
                        .init(color: Color(hex: 0x5C3A20), location: 0.4),
                        .init(color: Color(hex: 0x6F4525), location: 0.7),
                        .init(color: Color(hex: 0x4A2F18), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: bodyLength, height: bodyDiameter)
                .overlay(
                    // Faint wrapper veins
                    Canvas { ctx, size in
                        for i in 0 ..< 8 {
                            var path = Path()
                            let y = CGFloat(i) * size.height / 8 + 1
                            path.move(to: CGPoint(x: 4, y: y))
                            path.addLine(to: CGPoint(x: size.width - 4, y: y + 0.6))
                            ctx.stroke(path, with: .color(.black.opacity(0.18)), lineWidth: 0.4)
                        }
                    }
                    .clipShape(Capsule())
                )
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 4)

            // Band (gold ring near the foot)
            Rectangle()
                .fill(LinearGradient(
                    colors: [FTColor.gold, FTColor.goldLo],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: bodyDiameter * 0.6, height: bodyDiameter)
                .offset(x: bodyLength * 0.62)
                .overlay(
                    Rectangle()
                        .strokeBorder(FTColor.goldHi.opacity(0.7), lineWidth: 0.5)
                        .frame(width: bodyDiameter * 0.6, height: bodyDiameter)
                        .offset(x: bodyLength * 0.62)
                )

            // Foot ember — radial bloom that grows with ignitedAmount
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Color(hex: 0xFFE8B0).opacity(0.9 * ignitedAmount),
                            Color(hex: 0xFF6A1A).opacity(0.7 * ignitedAmount),
                            .clear,
                        ],
                        center: .center, startRadius: 0,
                        endRadius: bodyDiameter * (0.6 + 0.4 * ignitedAmount)
                    ))
                    .frame(width: bodyDiameter * 2.4, height: bodyDiameter * 2.4)
                    .blur(radius: 4)

                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color(hex: 0xFFFCE8).opacity(ignitedAmount),
                            Color(hex: 0xFF8030).opacity(0.85 * ignitedAmount),
                            Color(hex: 0xC04A1E).opacity(0.4 * ignitedAmount),
                        ],
                        startPoint: .center, endPoint: .bottomTrailing
                    ))
                    .frame(width: bodyDiameter * 0.85, height: bodyDiameter * 0.85)
            }
            .offset(x: -bodyDiameter * 0.35)
            .accessibilityHidden(true)
        }
        .frame(width: bodyLength + bodyDiameter * 1.5, height: bodyDiameter * 2.4)
        .compositingGroup()
    }
}
