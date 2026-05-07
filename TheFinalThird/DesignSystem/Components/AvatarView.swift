import SwiftUI

struct AvatarView: View {
    let url: URL?
    let initials: String
    var size: CGFloat = 36
    var isGhost: Bool = false
    var isActive: Bool = false
    /// Patron status — renders a faint gold ring around the avatar.
    /// Visible everywhere a face appears: chat, presence, doorway,
    /// active session, recap. Like a wedding band — quiet but real.
    var isPatron: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(FTColor.surfaceHi)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(strokeStyle, lineWidth: strokeWidth)
        )
        .overlay(patronRing)
        .opacity(isGhost ? 0.4 : 1)
        .accessibilityLabel(accessibilityText)
    }

    /// Patron mark — a slightly-outset gold ring that doesn't fight
    /// the active-state gold ring. When both are on, the patron ring
    /// sits just outside, hairline-fine.
    @ViewBuilder
    private var patronRing: some View {
        if isPatron {
            Circle()
                .stroke(FTColor.gold.opacity(0.85), lineWidth: 1)
                .frame(width: size + 4, height: size + 4)
                .shadow(color: FTColor.goldGlow.opacity(0.5), radius: 3)
                .accessibilityHidden(true)
        }
    }

    private var strokeStyle: Color {
        isActive ? FTColor.gold : FTColor.divider
    }

    private var strokeWidth: CGFloat {
        isActive ? 2 : 0.5
    }

    private var accessibilityText: String {
        var bits = [initials]
        if isGhost { bits.append("ghost mode") }
        if isPatron { bits.append("Patron") }
        return bits.joined(separator: ", ")
    }

    private var initialsView: some View {
        Text(initials)
            .font(FTType.caption(size * 0.4, weight: .semibold))
            .foregroundStyle(FTColor.inkMuted)
    }
}
