import SwiftUI

/// Custom dark tab bar — Home / Explore / Lounge / Journal / Profile.
///
/// Layout uses a VStack (not ZStack-with-bottom-overlay) so the tab bar
/// is structurally pinned to its content height — it can't expand
/// vertically into the content area above, which previously caused the
/// wood-floor texture to leak upward and block touches on cards in
/// Home, Lounge, and Journal.
struct MainTabView: View {
    enum Tab: Hashable, CaseIterable {
        case home, explore, lounge, journal, profile

        var label: String {
            switch self {
            case .home: return "Home"
            case .explore: return "Explore"
            case .lounge: return "Lounge"
            case .journal: return "Journal"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house"
            case .explore: return "magnifyingglass"
            case .lounge: return "person.2.fill"
            case .journal: return "book.closed"
            case .profile: return "person.crop.circle"
            }
        }
    }

    @State private var selection: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .home:    HomeView()
                case .explore: ExploreView()
                case .lounge:  LoungeView()
                case .journal: JournalView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FTTabBar(selection: $selection)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct FTTabBar: View {
    @Binding var selection: MainTabView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                Button {
                    HapticsService.shared.tap()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                selection == tab
                                ? AnyShapeStyle(.goldLeaf)
                                : AnyShapeStyle(FTColor.inkMuted)
                            )
                            .shadow(
                                color: selection == tab ? FTColor.goldGlow : .clear,
                                radius: 8, x: 0, y: 0
                            )
                        Text(tab.label)
                            .font(FTType.caption(10, weight: .medium))
                            .foregroundStyle(selection == tab ? FTColor.gold : FTColor.inkMuted)
                            .tracking(selection == tab ? 0.6 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FTSpace.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, FTSpace.md)
        .padding(.top, FTSpace.sm)
        // Bottom inset accounts for the home indicator. Computed from the
        // safe area we just opted out of at the parent level.
        .padding(.bottom, bottomSafeAreaInset)
        .background(FTFloorBackground())
        .overlay(alignment: .top) {
            GoldDivider().opacity(0.55)
        }
    }

    /// Manual safe-area inset since the parent VStack opts out of bottom
    /// safe area to let the wood floor extend behind the home indicator.
    private var bottomSafeAreaInset: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first
        else { return FTSpace.lg }
        return max(window.safeAreaInsets.bottom, FTSpace.lg)
    }
}
