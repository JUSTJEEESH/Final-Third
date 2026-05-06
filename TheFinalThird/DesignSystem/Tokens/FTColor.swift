import SwiftUI

/// Semantic color tokens for The Final Third.
/// Dark mode only — never reference UIColor system colors directly outside this file.
/// Gold is *meaning*, not decoration: reserved for state, intent, and ritual moments.
enum FTColor {
    // MARK: Surface
    static let background = Color(hex: 0x0B0908)         // near-black, warm
    static let surface    = Color(hex: 0x131110)         // raised
    static let surfaceHi  = Color(hex: 0x1B1816)         // raised + 1
    static let surfaceLo  = Color(hex: 0x070605)         // sunk
    static let divider    = Color(hex: 0x2A2522).opacity(0.6)

    // MARK: Ink
    static let ink        = Color(hex: 0xE8E2D8)         // primary text
    static let inkMuted   = Color(hex: 0x9A8F82)         // secondary text
    static let inkFaint   = Color(hex: 0x60564C)         // tertiary text
    static let inkInverse = Color(hex: 0x0B0908)

    // MARK: Gold (semantic)
    static let gold       = Color(hex: 0xC9A24A)         // primary gold
    static let goldHi     = Color(hex: 0xE3C26C)         // bloom
    static let goldLo     = Color(hex: 0x8E6F2F)         // pressed / muted
    static let goldGlow   = Color(hex: 0xFFD56B).opacity(0.45)

    // MARK: Ember (lighting / streak)
    static let ember      = Color(hex: 0xFF6A1A)
    static let emberHot   = Color(hex: 0xFFB347)
    static let emberCore  = Color(hex: 0xFFE8B0)

    // MARK: State
    static let success    = Color(hex: 0x6FA77B)
    static let warning    = Color(hex: 0xC9A24A)
    static let danger     = Color(hex: 0xB04A3A)

    // MARK: Overlays
    static let scrim      = Color.black.opacity(0.6)
    static let vignette   = Color.black.opacity(0.85)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
