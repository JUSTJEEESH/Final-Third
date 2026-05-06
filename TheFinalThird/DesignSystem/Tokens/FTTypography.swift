import SwiftUI

/// Typography tokens. Uses system fonts to avoid external dependencies; the
/// "display" face uses `.serif` with optical sizing — replace with a licensed
/// face (e.g. GT Sectra, Canela) in `Resources` later if desired.
enum FTType {
    // Display — used for ritual moments (cigar reveal, final third, drops)
    static func display(_ size: CGFloat = 34, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // Heading
    static func heading(_ size: CGFloat = 22, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // Body
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bodyMono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // Caption / label
    static func caption(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
