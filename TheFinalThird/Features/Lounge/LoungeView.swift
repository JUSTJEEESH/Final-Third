import SwiftUI

struct LoungeView: View {
    @State private var vm = LoungeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                content
            }
            .navigationDestination(for: AppRoute.self) { route in
                if case let .room(id) = route { RoomView(roomID: id) }
            }
            .navigationBarHidden(true)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                header
                if vm.isLoading && vm.rooms.isEmpty {
                    FTLoadingView(label: "Looking for open rooms…")
                        .frame(height: 240)
                } else if let error = vm.error, vm.rooms.isEmpty {
                    FTErrorView(message: error) {
                        Task { await vm.load() }
                    }
                    .frame(height: 240)
                } else if vm.rooms.isEmpty {
                    FTEmptyView(
                        symbol: "smoke",
                        title: "Quiet so far tonight.",
                        subtitle: "Step in. Someone always shows up."
                    )
                } else {
                    LazyVStack(spacing: FTSpace.md) {
                        ForEach(vm.rooms) { room in
                            NavigationLink(value: AppRoute.room(room.id)) {
                                RoomRow(room: room, occupants: vm.occupants[room.id] ?? 0)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.top, FTSpace.md)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lounge")
                .font(FTType.display(34))
                .foregroundStyle(FTColor.gold)
            Text("Choose a chair.")
                .font(FTType.body(14))
                .foregroundStyle(FTColor.inkMuted)
        }
        .padding(.top, FTSpace.lg)
    }
}

private struct RoomRow: View {
    let room: Room
    let occupants: Int

    var body: some View {
        FTCard(elevated: true) {
            HStack(alignment: .center, spacing: FTSpace.md) {
                Circle()
                    .fill(occupants > 0 ? FTColor.gold : FTColor.divider)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(FTType.body(17, weight: .semibold))
                    if let theme = room.theme {
                        Text(theme).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                    } else if let desc = room.description {
                        Text(desc).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if occupants > 0 {
                    Text("\(occupants)")
                        .font(FTType.caption(12, weight: .semibold))
                        .padding(.horizontal, FTSpace.sm).padding(.vertical, 4)
                        .background(FTColor.surfaceHi).clipShape(Capsule())
                }
                Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
            }
        }
    }
}
