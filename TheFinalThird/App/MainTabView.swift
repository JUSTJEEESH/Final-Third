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
            switch selection {
            case .home:    HomePlaceholder()
            case .explore: ExploreView()
            case .lounge:  LoungeView()
            case .journal: JournalPlaceholder()
            case .profile: ProfilePlaceholder()
            }

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
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(tab.label).font(FTType.caption(10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selection == tab ? FTColor.gold : FTColor.inkMuted)
                    .padding(.vertical, FTSpace.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, FTSpace.md)
        .padding(.top, FTSpace.sm)
        .padding(.bottom, FTSpace.lg)
        .background(FTColor.surfaceLo)
        .overlay(alignment: .top) { GoldDivider().opacity(0.4) }
    }
}

// MARK: Placeholders (real features land in Features/*)

private struct HomePlaceholder: View {
    var body: some View { CenteredTitle("Home", subtitle: "Tonight's pick lands here.") }
}

private struct JournalPlaceholder: View {
    var body: some View { CenteredTitle("Journal", subtitle: "Your sessions, kept.") }
}

private struct ProfilePlaceholder: View {
    var body: some View { CenteredTitle("Profile", subtitle: "Your chair, your ritual.") }
}

private struct CenteredTitle: View {
    let title: String
    let subtitle: String
    init(_ title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }

    var body: some View {
        VStack(spacing: FTSpace.sm) {
            Text(title).font(FTType.display(36)).foregroundStyle(FTColor.gold)
            Text(subtitle).font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}
