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
            .background(backgroundView)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(borderColor, lineWidth: FTStroke.thin)
            )
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Working" : "")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .gold:
            ZStack {
                Rectangle().fill(.goldLeaf)
                Rectangle().fill(.goldHighlight).blendMode(.screen)
            }
        case .ghost:
            ZStack {
                FTColor.surface
                TexturePanel(texture: .leather, opacity: 0.08)
            }
        case .ember:
            LinearGradient(
                stops: [
                    .init(color: FTColor.emberCore, location: 0),
                    .init(color: FTColor.emberHot,  location: 0.4),
                    .init(color: FTColor.ember,     location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .danger:
            FTColor.danger
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
        case .gold:  return FTColor.goldDeep.opacity(0.7)
        default:     return .clear
        }
    }

    private var shadowColor: Color {
        switch style {
        case .gold:   return FTColor.goldDeep.opacity(0.45)
        case .ember:  return FTColor.ember.opacity(0.45)
        case .ghost:  return .black.opacity(0.25)
        case .danger: return FTColor.danger.opacity(0.4)
        }
    }
}
