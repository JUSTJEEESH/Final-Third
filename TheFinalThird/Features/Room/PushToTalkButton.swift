import SwiftUI

/// Press-and-hold gold capsule. Shows a transmitting ring while held.
struct PushToTalkButton: View {
    let isTransmitting: Bool
    let isJoined: Bool
    let onPressChange: (Bool) -> Void

    @State private var ringScale: CGFloat = 1

    var body: some View {
        ZStack {
            if isTransmitting {
                Circle()
                    .stroke(FTColor.gold.opacity(0.6), lineWidth: 2)
                    .scaleEffect(ringScale)
                    .opacity(2 - ringScale)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: ringScale
                    )
                    .onAppear { ringScale = 1.6 }
                    .onDisappear { ringScale = 1 }
            }
            Image(systemName: isTransmitting ? "mic.fill" : "mic")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isTransmitting ? FTColor.inkInverse : FTColor.gold)
                .padding(18)
                .background(isTransmitting ? FTColor.gold : FTColor.surfaceHi)
                .clipShape(Circle())
                .overlay(Circle().stroke(FTColor.gold.opacity(isTransmitting ? 0 : 0.4), lineWidth: 1))
        }
        .frame(width: 64, height: 64)
        .opacity(isJoined ? 1 : 0.4)
        .accessibilityLabel(isTransmitting ? "Transmitting voice" : "Push to talk")
        .accessibilityAddTraits(.isButton)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isJoined && !isTransmitting {
                        HapticsService.shared.tap()
                        onPressChange(true)
                    }
                }
                .onEnded { _ in
                    if isTransmitting {
                        HapticsService.shared.soft()
                        onPressChange(false)
                    }
                }
        )
    }
}
