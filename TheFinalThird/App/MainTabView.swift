import SwiftUI

/// Custom dark tab bar — Home / Explore / Lounge / Journal / Profile.
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
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .home:    HomeView()
                case .explore: ExploreView()
                case .lounge:  LoungeView()
                case .journal: JournalView()
                case .profile: ProfileView()
                }
            }
            .padding(.bottom, 64) // tab bar overlay clearance

            FTTabBar(selection: $selection)
        }
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
                                color: selection == tab
                                    ? FTColor.goldGlow
                                    : .clear,
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
        .padding(.bottom, FTSpace.lg)
        .background(FTFloorBackground())
        .overlay(alignment: .top) {
            GoldDivider().opacity(0.55)
        }
    }
}
