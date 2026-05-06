import SwiftUI

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(DeepLinkRouter.self) private var router
    @State private var vm: HomeViewModel?

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
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Greeting(name: vm.profile?.displayName, greeting: vm.greeting,
                         streak: vm.usual?.streakCount ?? 0)
                if let cigar = vm.tonightsPick { TonightsPick(cigar: cigar) }
                if let usual = vm.usual { YourRitual(usual: usual, cigar: vm.usualCigar) }
                if let drop = vm.currentDrop, let cigar = vm.dropCigar {
                    DropOfTheWeek(drop: drop, cigar: cigar)
                }
                ActiveRooms(rooms: vm.activeRooms)
                if !vm.nearbyEvents.isEmpty {
                    NearbyTonight(events: vm.nearbyEvents, city: vm.profile?.city)
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, 96)
        }
    }
}

private struct Greeting: View {
    let name: String?
    let greeting: String
    let streak: Int

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(FTType.display(28)).foregroundStyle(FTColor.gold)
                if let name { Text(name).font(FTType.body(14)).foregroundStyle(FTColor.inkMuted) }
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
                FTCard(elevated: true) {
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

private struct ActiveRooms: View {
    let rooms: [Room]

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Active Rooms")
            if rooms.isEmpty {
                Text("Nothing yet — be the first to step in.")
                    .font(FTType.caption(13)).foregroundStyle(FTColor.inkMuted)
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
