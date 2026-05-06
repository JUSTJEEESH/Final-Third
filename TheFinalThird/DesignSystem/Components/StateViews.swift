import SwiftUI

/// Quiet, atmosphere-preserving placeholders for empty / loading / error
/// states. Avoid bright colors; prefer copy that sounds like the room.
struct FTLoadingView: View {
    var label: String?
    var body: some View {
        VStack(spacing: FTSpace.md) {
            ProgressView().tint(FTColor.gold)
            if let label {
                Text(label).font(FTType.caption(13)).foregroundStyle(FTColor.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(label ?? "Loading")
    }
}

struct FTEmptyView: View {
    let symbol: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: FTSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(FTColor.inkFaint)
            Text(title).font(FTType.body(15)).foregroundStyle(FTColor.inkMuted)
            if let subtitle {
                Text(subtitle).font(FTType.caption(12)).foregroundStyle(FTColor.inkFaint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpace.xxl)
        .accessibilityElement(children: .combine)
    }
}

struct FTErrorView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: FTSpace.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(FTColor.danger)
            Text(message).font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FTSpace.xl)
            if let retry {
                Button {
                    HapticsService.shared.tap()
                    retry()
                } label: {
                    Text("Try again")
                        .font(FTType.caption(12, weight: .semibold))
                        .padding(.horizontal, FTSpace.md).padding(.vertical, FTSpace.sm)
                        .background(FTColor.surfaceHi)
                        .clipShape(Capsule())
                        .foregroundStyle(FTColor.gold)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
