import SwiftUI
import Testing
import SnapshotTesting
@testable import TheFinalThird

/// Snapshot tests for the parts of the design system most likely to drift:
/// gold tokens, button styles, ember badge thresholds. Captures at a fixed
/// device size on the dark scheme.
@Suite("Design tokens — gold + components")
@MainActor
struct DesignTokenSnapshotTests {
    private let layout = SwiftUISnapshotting.fixed(width: 320, height: 120)

    @Test("FTButton gold style")
    func buttonGold() {
        let view = FTButton(title: "Become a member", style: .gold) {}
            .padding()
            .frame(width: 320)
            .background(FTColor.background)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: layout))
    }

    @Test("FTButton ghost style")
    func buttonGhost() {
        let view = FTButton(title: "Continue with email", style: .ghost) {}
            .padding()
            .frame(width: 320)
            .background(FTColor.background)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: layout))
    }

    @Test("EmberBadge — none / Ember / Flame / Fire thresholds")
    func emberBadgeThresholds() {
        let view = HStack(spacing: 8) {
            EmberBadge(streakCount: 0)
            EmberBadge(streakCount: 1)
            EmberBadge(streakCount: 7)
            EmberBadge(streakCount: 30)
        }
        .padding()
        .background(FTColor.background)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: layout))
    }

    @Test("AvatarView — active vs ghost")
    func avatarStates() {
        let view = HStack(spacing: 12) {
            AvatarView(url: nil, initials: "MA", isActive: true)
            AvatarView(url: nil, initials: "JS", isActive: false)
            AvatarView(url: nil, initials: "RV", isGhost: true)
        }
        .padding()
        .background(FTColor.background)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: layout))
    }
}

private enum SwiftUISnapshotting {
    static func fixed(width: CGFloat, height: CGFloat) -> SwiftUISnapshotLayout {
        .fixed(width: width, height: height)
    }
}
