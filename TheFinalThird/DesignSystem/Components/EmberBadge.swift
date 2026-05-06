import SwiftUI

/// Streak indicator: Ember → Flame → Fire across thresholds.
struct EmberBadge: View {
    let streakCount: Int

    var body: some View {
        HStack(spacing: FTSpace.xs) {
            Image(systemName: symbol)
                .foregroundStyle(LinearGradient(
                    colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                    startPoint: .top, endPoint: .bottom
                ))
            Text("\(streakCount)")
                .font(FTType.caption(13, weight: .semibold))
        }
        .padding(.horizontal, FTSpace.sm)
        .padding(.vertical, FTSpace.xs)
        .background(FTColor.surfaceHi)
        .clipShape(Capsule())
        .accessibilityLabel("Streak \(streakCount) nights")
    }

    private var symbol: String {
        switch streakCount {
        case 0:        return "circle"
        case 1...6:    return "circle.dotted.circle"
        case 7...29:   return "flame"
        default:       return "flame.fill"
        }
    }
}
