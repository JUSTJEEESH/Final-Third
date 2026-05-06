import SwiftUI

/// Visualizes the cigar's burn progress in thirds. The final third triggers
/// a slow gold pulse (PRD: emotional anchor + identity).
struct BurnTimerView: View {
    let session: Session
    @State private var now: Date = .now

    var body: some View {
        VStack(spacing: FTSpace.md) {
            ringView
            HStack {
                Text(elapsedText).font(FTType.bodyMono(13)).foregroundStyle(FTColor.inkMuted)
                Spacer()
                Text(thirdLabel).font(FTType.caption(12, weight: .semibold))
                    .foregroundStyle(isFinal ? FTColor.gold : FTColor.inkMuted)
                    .textCase(.uppercase)
            }
        }
        .padding(FTSpace.lg)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: FTRadius.lg)
                .stroke(isFinal ? FTColor.gold.opacity(pulse) : FTColor.divider, lineWidth: isFinal ? 1.5 : 0.5)
        )
        .onReceive(timer) { _ in now = .now }
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var pulse: Double = 0.5

    private var ringView: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LinearGradient(
                    colors: [FTColor.ember, FTColor.emberHot, FTColor.gold],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(FTMotion.easeOutSoft, value: progress)
            Circle().stroke(FTColor.divider, lineWidth: 1)
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(FTColor.ember)
                Text("\(Int(progress * 100))%").font(FTType.bodyMono(15))
            }
        }
        .frame(width: 96, height: 96)
        .onAppear {
            if isFinal {
                withAnimation(FTMotion.goldPulse) { pulse = 1.0 }
            }
        }
    }

    private var elapsed: TimeInterval { now.timeIntervalSince(session.startedAt) }

    private var elapsedText: String {
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var progress: Double {
        // estimate against a typical 1h burn — caps at 1.0
        min(elapsed / (60 * 60), 1.0)
    }

    private var thirdLabel: String {
        switch session.currentThird(now: now) {
        case .first?: return "First third"
        case .middle?: return "Middle"
        case .final?: return "Final third"
        case nil: return ""
        }
    }

    private var isFinal: Bool { session.currentThird(now: now) == .final }
}
