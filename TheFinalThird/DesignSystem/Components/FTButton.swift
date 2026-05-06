import SwiftUI

/// Primary button styles for The Final Third.
struct FTButton: View {
    enum Style { case gold, ghost, ember, danger }

    let title: String
    var style: Style = .gold
    var icon: String?
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.shared.tap()
            action()
        } label: {
            HStack(spacing: FTSpace.sm) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).font(FTType.body(16, weight: .medium))
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(borderColor, lineWidth: FTStroke.thin)
            )
        }
        .disabled(isLoading)
    }

    private var background: some ShapeStyle {
        switch style {
        case .gold:   return AnyShapeStyle(LinearGradient(colors: [FTColor.gold, FTColor.goldLo],
                                                          startPoint: .top, endPoint: .bottom))
        case .ghost:  return AnyShapeStyle(FTColor.surface)
        case .ember:  return AnyShapeStyle(LinearGradient(colors: [FTColor.emberHot, FTColor.ember],
                                                          startPoint: .top, endPoint: .bottom))
        case .danger: return AnyShapeStyle(FTColor.danger)
        }
    }

    private var foreground: Color {
        switch style {
        case .gold, .ember: return FTColor.inkInverse
        case .ghost:        return FTColor.ink
        case .danger:       return FTColor.ink
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost: return FTColor.divider
        default:     return .clear
        }
    }
}
