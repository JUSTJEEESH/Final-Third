import SwiftUI

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(DeepLinkRouter.self) private var router
    @State private var vm: HomeViewModel?
    @State private var showLightUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                if let vm { content(vm) } else { ProgressView().tint(FTColor.gold) }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .room(let id):  RoomView(roomID: id)
                case .cigar(let id): CigarDetailView(cigarID: id)
                default: EmptyView()
                }
            }
        }
        .task {
            if vm == nil, case .signedIn(let userID) = container.auth.state {
                vm = HomeViewModel(
                    userID: userID,
                    config: container.config
                )
                await vm?.load()
            }
        }
        .fullScreenCover(isPresented: $showLightUp) {
            if case .signedIn(let userID) = container.auth.state {
                SessionFlowView(userID: userID, roomID: nil,
                                isGhost: vm?.profile?.ghostModeDefault ?? false)
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Greeting(name: vm.profile?.displayName, greeting: vm.greeting,
                         streak: vm.usual?.streakCount ?? 0)
                lightUpButton
                if let cigar = vm.tonightsPick { TonightsPick(cigar: cigar) }
                if let usual = vm.usual { YourRitual(usual: usual, cigar: vm.usualCigar) }
                if let drop = vm.currentDrop, let cigar = vm.dropCigar {
                    DropOfTheWeek(drop: drop, cigar: cigar)
                } else if let upcoming = vm.upcomingDrop, let cigar = vm.upcomingDropCigar {
                    UpcomingDropTeaser(drop: upcoming, cigar: cigar)
                }
                ActiveRooms(rooms: vm.activeRooms)
                if !vm.nearbyEvents.isEmpty {
                    NearbyTonight(events: vm.nearbyEvents, city: vm.profile?.city)
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private var lightUpButton: some View {
        Button {
            HapticsService.shared.tap()
            showLightUp = true
        } label: {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(LinearGradient(
                        colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .font(.system(size: 22))
                    .shadow(color: FTColor.ember.opacity(0.6), radius: 10, x: 0, y: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Light up").font(FTType.heading(18, weight: .semibold))
                    Text("Choose your cigar and step in.")
                        .font(FTType.caption(11))
                        .foregroundStyle(FTColor.inkInverse.opacity(0.7))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(FTColor.inkInverse)
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(GoldSurface())
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(FTColor.goldDeep.opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: FTColor.goldDeep.opacity(0.55), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Light up — start a session")
    }
}

private struct Greeting: View {
    let name: String?
    let greeting: String
    let streak: Int

    /// First name only — feels personal without ever sounding formal.
    private var firstName: String? {
        guard let name else { return nil }
        return name.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(FTType.display(28))
                    .foregroundStyle(FTColor.gold)
                if let firstName {
                    Text(firstName)
                        .font(FTType.display(38, weight: .semibold))
                        .foregroundStyle(FTColor.ink)
                        .padding(.top, 2)
                }
            }
            Spacer()
            if streak > 0 { EmberBadge(streakCount: streak) }
        }
        .padding(.top, FTSpace.lg)
    }
}

private struct TonightsPick: View {
    let cigar: Cigar

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Tonight's Pick")
            NavigationLink(value: AppRoute.cigar(cigar.id)) {
                FTCard(elevated: true,
                       texture: .tobaccoLeaf,
                       textureIntensity: 0.20,
                       textureZoom: 1.6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cigar.brand.uppercased())
                                .font(FTType.caption(11, weight: .semibold))
                                .foregroundStyle(FTColor.gold).tracking(1.4)
                            Text(cigar.line).font(FTType.heading(20))
                            if let v = cigar.vitola {
                                Text(v).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                            }
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .foregroundStyle(LinearGradient(
                                colors: [FTColor.emberCore, FTColor.ember],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .font(.system(size: 28))
                            .shadow(color: FTColor.ember.opacity(0.55),
                                    radius: 10, x: 0, y: 0)
                    }
                }
            }.buttonStyle(.plain)
        }
    }
}

private struct YourRitual: View {
    let usual: Usual
    let cigar: Cigar?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Your Ritual")
            FTCard {
                VStack(alignment: .leading, spacing: 4) {
                    if let time = usual.preferredTime {
                        Text(timeString(time))
                            .font(FTType.caption(11, weight: .semibold))
                            .foregroundStyle(FTColor.gold)
                    }
                    Text(cigar?.displayName ?? "Set your usual")
                        .font(FTType.body(15, weight: .medium))
                    Text(usual.enabled ? "We'll remind you." : "Reminders off.")
                        .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                }
            }
        }
    }

    private func timeString(_ t: TimeOfDay) -> String {
        var components = DateComponents(); components.hour = t.hour; components.minute = t.minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened).uppercased()
    }
}

private struct DropOfTheWeek: View {
    let drop: CigarDrop
    let cigar: Cigar

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Drop of the Week")
            FTCard(elevated: true) {
                VStack(alignment: .leading, spacing: FTSpace.sm) {
                    Text(cigar.brand.uppercased())
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.gold).tracking(1.4)
                    Text(cigar.line).font(FTType.display(22))
                    if let copy = drop.heroCopy {
                        Text(copy).font(FTType.body(14))
                            .foregroundStyle(FTColor.ink.opacity(0.85))
                    }
                    if drop.isLive {
                        Text("Live now")
                            .font(FTType.caption(10, weight: .semibold))
                            .padding(.horizontal, FTSpace.sm)
                            .padding(.vertical, 4)
                            .background(FTColor.gold)
                            .foregroundStyle(FTColor.inkInverse)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private struct UpcomingDropTeaser: View {
    let drop: CigarDrop
    let cigar: Cigar

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Coming Soon")
            FTCard {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(FTColor.gold)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cigar.brand.uppercased())
                            .font(FTType.caption(10, weight: .semibold))
                            .foregroundStyle(FTColor.gold).tracking(1.2)
                        Text(cigar.line)
                            .font(FTType.body(15, weight: .semibold))
                        Text(whenText)
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    private var whenText: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: .now, to: drop.startsAt).day ?? 0
        if days <= 0 { return "Lighting up today" }
        if days == 1 { return "Tomorrow" }
        if days < 7 {
            return drop.startsAt.formatted(.dateTime.weekday(.wide))
        }
        return drop.startsAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct ActiveRooms: View {
    let rooms: [Room]

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Active Rooms")
            if rooms.isEmpty {
                FTCard {
                    HStack(spacing: FTSpace.md) {
                        Image(systemName: "smoke")
                            .foregroundStyle(FTColor.inkFaint)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet so far tonight.")
                                .font(FTType.body(14, weight: .medium))
                            Text("Step in. Someone always shows up.")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(rooms) { room in
                    NavigationLink(value: AppRoute.room(room.id)) {
                        FTCard {
                            HStack {
                                Circle().fill(FTColor.gold).frame(width: 6, height: 6)
                                Text(room.name).font(FTType.body(15, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(FTColor.inkFaint)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

private struct NearbyTonight: View {
    let events: [LoungeEvent]
    let city: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle(city.map { "Nearby \($0)" } ?? "Nearby Tonight")
            ForEach(events) { event in
                FTCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).font(FTType.body(15, weight: .medium))
                        if let when = event.datetime {
                            Text(when, style: .relative)
                                .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                        }
                    }
                }
            }
        }
    }
}

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(FTType.caption(11, weight: .semibold))
        .foregroundStyle(FTColor.inkMuted)
        .textCase(.uppercase)
        .tracking(1)
}
