import SwiftUI

struct AvatarView: View {
    let url: URL?
    let initials: String
    var size: CGFloat = 36
    var isGhost: Bool = false
    var isActive: Bool = false

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
                .stroke(isActive ? FTColor.gold : FTColor.divider, lineWidth: isActive ? 2 : 0.5)
        )
        .opacity(isGhost ? 0.4 : 1)
        .accessibilityLabel(isGhost ? "\(initials), ghost mode" : initials)
    }

    private var initialsView: some View {
        Text(initials)
            .font(FTType.caption(size * 0.4, weight: .semibold))
            .foregroundStyle(FTColor.inkMuted)
    }
}
