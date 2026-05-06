import SwiftUI

struct LoungeView: View {
    @State private var vm = LoungeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Lounge")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(FTColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView().tint(FTColor.gold)
        } else if vm.rooms.isEmpty {
            EmptyLoungeView()
        } else {
            ScrollView {
                LazyVStack(spacing: FTSpace.md) {
                    ForEach(vm.rooms) { room in
                        NavigationLink(value: AppRoute.room(room.id)) {
                            RoomRow(room: room, occupants: vm.occupants[room.id] ?? 0)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FTSpace.lg)
                .padding(.top, FTSpace.md)
                .padding(.bottom, 96)
            }
            .navigationDestination(for: AppRoute.self) { route in
                if case let .room(id) = route { RoomView(roomID: id) }
            }
        }
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
            }
        }
    }
}

private struct EmptyLoungeView: View {
    var body: some View {
        VStack(spacing: FTSpace.md) {
            Image(systemName: "smoke").font(.system(size: 36))
                .foregroundStyle(FTColor.inkFaint)
            Text("Quiet so far tonight.")
                .font(FTType.body(15)).foregroundStyle(FTColor.inkMuted)
            Text("Step in. Someone always shows up.")
                .font(FTType.caption(12)).foregroundStyle(FTColor.inkFaint)
        }
    }
}
