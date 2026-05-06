import SwiftUI
import UIKit

/// Surface textures used across the app. Each case has a procedural Canvas
/// fallback AND looks for a matching photographic asset in
/// `Assets.xcassets` named after `assetName`. If the asset exists it's
/// preferred; otherwise the procedural fallback renders.
///
/// Drop a high-resolution seamless texture into Assets.xcassets with the
/// matching name and it'll automatically replace the procedural version
/// app-wide. Recommended sources:
///   - https://ambientcg.com  (CC0)
///   - https://polyhaven.com/textures  (CC0)
///   - https://www.cgbookcase.com  (CC0)
enum FTTexture: Sendable {
    case leather       // dark warm grain — chairs, cards
    case tobaccoLeaf   // warmer brown with curving veins — accents
    case charredWood   // black-brown with vertical grain + warm cracks — tab bar floor
    case agedPaper     // tan grain with subtle freckling — journal surfaces
    case smoke         // faint drifting haze — atmospheric overlay
    case goldLeaf      // metallic gold leaf foil — premium CTAs, ritual surfaces

    /// Asset catalog name the texture system looks for. If a UIImage exists
    /// for this name in Assets.xcassets, it's used in preference to the
    /// procedural Canvas drawing.
    var assetName: String {
        switch self {
        case .leather:     return "texture_leather"
        case .tobaccoLeaf: return "texture_tobacco"
        case .charredWood: return "texture_wood"
        case .agedPaper:   return "texture_paper"
        case .smoke:       return "texture_smoke"
        case .goldLeaf:    return "texture_gold"
        }
    }
}

/// Renders a texture. Prefers a photographic `UIImage` from
/// `Assets.xcassets` when one exists; falls back to a procedural Canvas
/// drawing otherwise. Use `.drawingGroup()` on the caller in tight scroll
/// contexts to bake the procedural path to a Metal layer.
struct TexturePanel: View {
    let texture: FTTexture
    var opacity: Double = 0.12
    var seed: Double = 1.0

    var body: some View {
        Group {
            if let asset = UIImage(named: texture.assetName) {
                // Simple resizable stretch — no aspect-fill, no clipping
                // games. Aspect-fill in SwiftUI sometimes leaks through
                // its parent's height proposal, which was making the wood
                // floor overflow above the tab bar. For organic textures
                // (wood grain, leather, tobacco fiber, paper) mild
                // horizontal/vertical stretch is invisible to the eye.
                Image(uiImage: asset)
                    .resizable()
                    .interpolation(.high)
            } else {
                proceduralCanvas
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var proceduralCanvas: some View {
        Canvas { context, size in
            switch texture {
            case .leather:     drawLeather(&context, size: size)
            case .tobaccoLeaf: drawTobaccoLeaf(&context, size: size)
            case .charredWood: drawCharredWood(&context, size: size)
            case .agedPaper:   drawAgedPaper(&context, size: size)
            case .smoke:       drawSmoke(&context, size: size)
            case .goldLeaf:    drawGoldLeaf(&context, size: size)
            }
        }
        .drawingGroup()
    }

    // MARK: Deterministic noise helpers

    private func n(_ v: Double) -> Double { sin(v * 12.9898 + seed * 78.233) * 43758.5453 }
    private func r(_ a: Double, _ b: Double = 1) -> Double {
        let x = n(a + b * 31.7)
        return x - floor(x)
    }

    // MARK: Leather

    private func drawLeather(_ ctx: inout GraphicsContext, size: CGSize) {
        // Base — slight directional warmth from upper-left.
        let rect = Path(CGRect(origin: .zero, size: size))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [
                Color(hex: 0x2C1B12),
                Color(hex: 0x1A100A),
                Color(hex: 0x231711),
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: size.height)
        ))

        // Grain — many tiny specks of two colors.
        let grainCount = Int(min(size.width * size.height / 700, 2400))
        for i in 0 ..< grainCount {
            let s = Double(i)
            let x = r(s) * size.width
            let y = r(s, 2) * size.height
            let radius = 0.4 + r(s, 3) * 0.6
            let dark = r(s, 4) > 0.5
            let alpha = 0.12 + r(s, 5) * 0.18
            let color = dark ? Color(hex: 0x070403) : Color(hex: 0x4A2F1E)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha))
            )
        }

        // Soft cracks — a few long curving strokes.
        for i in 0 ..< 8 {
            let s = Double(i) * 17.3
            let y = r(s) * size.height
            let startX = r(s, 2) * size.width * 0.35
            let endX = startX + size.width * (0.35 + r(s, 3) * 0.4)
            var path = Path()
            path.move(to: CGPoint(x: startX, y: y))
            path.addCurve(
                to: CGPoint(x: endX, y: y + (r(s, 4) - 0.5) * 5),
                control1: CGPoint(x: startX + (endX - startX) * 0.3,
                                  y: y + (r(s, 5) - 0.5) * 4),
                control2: CGPoint(x: startX + (endX - startX) * 0.7,
                                  y: y + (r(s, 6) - 0.5) * 4)
            )
            ctx.stroke(path,
                       with: .color(Color(hex: 0x080403).opacity(0.55)),
                       lineWidth: 0.4)
        }

        // Subtle highlight — top warmth, bottom darker.
        ctx.fill(rect, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0x3A2415).opacity(0.18), location: 0),
                .init(color: .clear, location: 0.4),
                .init(color: .black.opacity(0.20), location: 1.0),
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))
    }

    // MARK: Tobacco leaf

    private func drawTobaccoLeaf(_ ctx: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [
                Color(hex: 0x4A2F18),
                Color(hex: 0x2D1B0E),
                Color(hex: 0x3B2614),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))

        // Central spine + branching veins — long curving strokes from a midline.
        let spineX = size.width * 0.5
        for i in 0 ..< 14 {
            let s = Double(i) * 23.7
            let yStart = r(s) * size.height
            let yEnd = yStart + (size.height * 0.18) * (r(s, 2) > 0.5 ? 1 : -1)
            let xExtent = size.width * (0.3 + r(s, 3) * 0.45)
            let direction: CGFloat = r(s, 4) > 0.5 ? 1 : -1
            var path = Path()
            path.move(to: CGPoint(x: spineX, y: yStart))
            path.addCurve(
                to: CGPoint(x: spineX + direction * xExtent, y: yEnd),
                control1: CGPoint(x: spineX + direction * xExtent * 0.3,
                                  y: yStart + (yEnd - yStart) * 0.2),
                control2: CGPoint(x: spineX + direction * xExtent * 0.7,
                                  y: yStart + (yEnd - yStart) * 0.7)
            )
            ctx.stroke(path,
                       with: .color(Color(hex: 0x18100A).opacity(0.55)),
                       lineWidth: 0.6)
        }

        // Mottling specks
        for i in 0 ..< 800 {
            let s = Double(i) * 11.91
            let x = r(s) * size.width
            let y = r(s, 2) * size.height
            let radius = 0.3 + r(s, 3) * 0.4
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(Color(hex: 0x070302).opacity(0.18 + r(s, 4) * 0.12))
            )
        }
    }

    // MARK: Charred wood

    private func drawCharredWood(_ ctx: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [
                Color(hex: 0x0D0807),
                Color(hex: 0x16100C),
                Color(hex: 0x080503),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))

        // Vertical grain — many parallel lines with varied opacity & slight wobble.
        let staveWidth: CGFloat = 14
        var x: CGFloat = 0
        var idx = 0
        while x < size.width {
            let s = Double(idx) * 6.13
            let lineX = x + (r(s) - 0.5) * 4
            var path = Path()
            path.move(to: CGPoint(x: lineX, y: 0))
            for step in stride(from: 0, through: size.height, by: 12) {
                let dx = (r(s, 1 + step / 13) - 0.5) * 1.5
                path.addLine(to: CGPoint(x: lineX + dx, y: step))
            }
            ctx.stroke(path,
                       with: .color(.black.opacity(0.45 + r(s, 9) * 0.25)),
                       lineWidth: 0.7)
            // Occasional warm crack
            if r(s, 11) > 0.78 {
                ctx.stroke(path,
                           with: .color(Color(hex: 0xC04A1E).opacity(0.10)),
                           lineWidth: 0.4)
            }
            x += staveWidth + (r(s, 13) - 0.5) * 4
            idx += 1
        }

        // Top + bottom edges darker (board joinery suggestion)
        ctx.fill(rect, with: .linearGradient(
            Gradient(stops: [
                .init(color: .black.opacity(0.45), location: 0),
                .init(color: .clear, location: 0.15),
                .init(color: .clear, location: 0.85),
                .init(color: .black.opacity(0.55), location: 1.0),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
    }

    // MARK: Aged paper

    private func drawAgedPaper(_ ctx: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [
                Color(hex: 0x3D3024),
                Color(hex: 0x261C13),
                Color(hex: 0x3A2D20),
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: size.height)
        ))
        for i in 0 ..< 1500 {
            let s = Double(i) * 9.71
            let x = r(s) * size.width
            let y = r(s, 2) * size.height
            let radius = 0.3 + r(s, 3) * 0.5
            let warm = r(s, 4) > 0.7
            let color = warm ? Color(hex: 0x5C3F22) : Color(hex: 0x130C07)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(0.22))
            )
        }
    }

    // MARK: Gold leaf

    private func drawGoldLeaf(_ ctx: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))
        ctx.fill(rect, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0xE3C26C), location: 0.00),
                .init(color: Color(hex: 0xC9A24A), location: 0.45),
                .init(color: Color(hex: 0x8E6F2F), location: 0.85),
                .init(color: Color(hex: 0x644A1E), location: 1.00),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
        // Hammered foil specks
        for i in 0 ..< 800 {
            let s = Double(i) * 19.7
            let x = r(s) * size.width
            let y = r(s, 2) * size.height
            let radius = 0.3 + r(s, 3) * 0.5
            let bright = r(s, 4) > 0.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color((bright ? Color(hex: 0xFFE49C) : Color(hex: 0x4A3712))
                                .opacity(0.20))
            )
        }
    }

    // MARK: Smoke

    private func drawSmoke(_ ctx: inout GraphicsContext, size: CGSize) {
        for i in 0 ..< 60 {
            let s = Double(i) * 27.13
            let x = r(s) * size.width
            let y = r(s, 2) * size.height
            let radius = 30 + r(s, 3) * 80
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(Color(hex: 0x3A322B).opacity(0.05))
            )
        }
    }
}

// MARK: - Convenience modifier

extension View {
    /// Layers a procedural texture behind the view using one of the
    /// design system surface colors as the base. Texture overlays at
    /// `intensity` (0–1) opacity so the base color still shows through.
    func ftSurface(
        _ base: Color = FTColor.background,
        texture: FTTexture? = nil,
        intensity: Double = 0.10
    ) -> some View {
        background(
            ZStack {
                base
                if let texture {
                    TexturePanel(texture: texture, opacity: intensity)
                }
            }
            .ignoresSafeArea()
        )
    }
}
