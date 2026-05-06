import SwiftUI

@MainActor
@Observable
final class DropsViewModel {
    var current: CigarDrop?
    var currentCigar: Cigar?
    var upcoming: [CigarDrop] = []
    var isLoading = false

    private let drops: DropRepository
    private let cigars: CigarRepository

    init(drops: DropRepository = LiveDropRepository(), cigars: CigarRepository = LiveCigarRepository()) {
        self.drops = drops
        self.cigars = cigars
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        async let currentTask: CigarDrop? = (try? await drops.current())
        async let upcomingTask: [CigarDrop] = (try? await drops.upcoming(limit: 5)) ?? []
        current = await currentTask
        upcoming = await upcomingTask
        if let cigarID = current?.cigarID {
            currentCigar = try? await cigars.fetch(id: cigarID)
        }
    }
}

struct DropsView: View {
    @State private var vm = DropsViewModel()

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpace.lg) {
                    Text("Drops").font(FTType.display(34)).foregroundStyle(FTColor.gold)
                        .padding(.top, FTSpace.lg)

                    if let drop = vm.current, let cigar = vm.currentCigar {
                        FTCard(elevated: true) {
                            VStack(alignment: .leading, spacing: FTSpace.sm) {
                                Text("Live").font(FTType.caption(10, weight: .semibold))
                                    .padding(.horizontal, FTSpace.sm).padding(.vertical, 4)
                                    .background(FTColor.gold)
                                    .foregroundStyle(FTColor.inkInverse)
                                    .clipShape(Capsule())
                                Text(cigar.brand.uppercased())
                                    .font(FTType.caption(11, weight: .semibold))
                                    .foregroundStyle(FTColor.gold).tracking(1.4)
                                Text(cigar.line).font(FTType.display(26))
                                if let copy = drop.heroCopy {
                                    Text(copy).font(FTType.body(14))
                                        .foregroundStyle(FTColor.ink.opacity(0.85))
                                }
                                Text("Ends \(drop.endsAt, style: .relative)")
                                    .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                            }
                        }
                    } else {
                        Text("No drop live right now. Check back tomorrow.")
                            .font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
                    }

                    if !vm.upcoming.isEmpty {
                        Text("Coming up").font(FTType.caption(11, weight: .semibold))
                            .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
                        ForEach(vm.upcoming) { drop in
                            FTCard {
                                HStack {
                                    Text(drop.startsAt, style: .relative).font(FTType.body(14))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(FTColor.inkFaint)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, FTSpace.lg)
                .padding(.bottom, FTSpace.lg)
            }
        }
        .task { await vm.load() }
    }
}
