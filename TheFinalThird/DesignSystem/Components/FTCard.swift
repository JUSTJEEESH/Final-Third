import SwiftUI

struct FTCard<Content: View>: View {
    var padding: CGFloat = FTSpace.lg
    var elevated: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(elevated ? FTColor.surfaceHi : FTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
            )
    }
}

struct GoldDivider: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, FTColor.gold.opacity(0.6), .clear],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 1)
    }
}
