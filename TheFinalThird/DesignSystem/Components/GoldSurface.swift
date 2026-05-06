import SwiftUI
import UIKit

/// A premium gold surface that prefers the photoreal PBR set
/// (`gold_color` + `gold_normal` + `gold_roughness` + `gold_metalness`)
/// when those assets are loaded into Assets.xcassets, and gracefully
/// falls back to the procedural `.goldLeaf` gradient otherwise.
///
/// Use this on every CTA, ritual surface, or band ring that should
/// read as actual gold leaf. The fallback path means it ships
/// without assets and progressively enhances when you drop them in.
struct GoldSurface: View {
    /// Slightly higher exposure works for gold; metallics need more light
    /// to read as bright. Tune per surface if needed.
    var exposure: CGFloat = 1.55

    /// How much of the texture fits into the view. >1 zooms in, showing
    /// more grain detail; <1 zooms out, showing more pattern variation.
    var coverage: CGFloat = 1.6

    /// Soft white highlight strip on top — applied over either path so
    /// a flat gradient and a PBR surface share the same edge treatment.
    var addHighlight: Bool = true

    var body: some View {
        ZStack {
            if hasGoldPBR {
                PBRMaterialView(set: "gold", exposure: exposure, coverage: coverage)
            } else {
                Rectangle().fill(.goldLeaf)
            }
            if addHighlight {
                Rectangle()
                    .fill(.goldHighlight)
                    .blendMode(.screen)
            }
        }
        // GoldSurface is always used as a non-interactive background; let
        // taps pass to whatever Button or NavigationLink it's living
        // inside.
        .allowsHitTesting(false)
    }

    /// At minimum we want the color map. The other maps are optional but
    /// having only the color makes PBR look identical to a flat fill, so
    /// require normal too — if at least the color + a normal exist, the
    /// surface will catch light.
    private var hasGoldPBR: Bool {
        UIImage(named: "gold_color") != nil
            && UIImage(named: "gold_normal") != nil
    }
}
