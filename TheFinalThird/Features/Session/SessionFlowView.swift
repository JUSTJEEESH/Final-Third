import SwiftUI

/// Full session entry flow — Step 1 cigar, Step 2 drink, Step 3 Lighting
/// Ceremony, then active session, then summary.
struct SessionFlowView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let userID: UUID
    let roomID: UUID?
    let isGhost: Bool

    @State private var vm: SessionViewModel?
    @State private var cigars: [Cigar] = []
    @State private var drinks: [Drink] = []

    private let cigarRepo: CigarRepository = LiveCigarRepository()
    private let drinkRepo: DrinkRepository = LiveDrinkRepository()

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            if let vm { phase(vm) } else { ProgressView().tint(FTColor.gold) }
        }
        .task {
            if vm == nil {
                vm = SessionViewModel(
                    userID: userID, roomID: roomID, isGhost: isGhost,
                    analytics: container.analytics
                )
            }
            await loadCatalog()
        }
    }

    @ViewBuilder
    private func phase(_ vm: SessionViewModel) -> some View {
        switch vm.phase {
        case .selectingCigar:
            cigarPicker(vm: vm)
        case .selectingDrink:
            drinkPicker(vm: vm)
        case .lighting:
            LightingCeremonyView(cigar: vm.cigar, method: vm.lightingMethod) {
                Task {
                    await vm.startSession()
                    container.analytics.track(.lightingCeremonyCompleted)
                }
            }
            .onAppear {
                container.analytics.track(.lightingCeremonyShown(method: vm.lightingMethod))
            }
        case .active:
            ActiveSessionView(vm: vm)
        case .summary:
            SessionSummaryView(vm: vm)
        case .finished:
            Color.clear.onAppear { dismiss() }
        }
    }

    private func loadCatalog() async {
        async let cigarsTask = (try? await cigarRepo.search(.init(), limit: 200)) ?? []
        async let drinksTask = (try? await drinkRepo.list(category: nil)) ?? []
        cigars = await cigarsTask
        drinks = await drinksTask
    }

    private func cigarPicker(vm: SessionViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                pickerHeader("Pick your cigar", subtitle: "Choose tonight's company.")
                ForEach(cigars) { cigar in
                    Button {
                        HapticsService.shared.tap()
                        vm.selectCigar(cigar)
                    } label: {
                        FTCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cigar.brand.uppercased())
                                        .font(FTType.caption(11, weight: .semibold))
                                        .foregroundStyle(FTColor.inkMuted)
                                    Text(cigar.line).font(FTType.body(16, weight: .medium))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.bottom, FTSpace.xxxl)
        }
    }

    private func drinkPicker(vm: SessionViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                pickerHeader("Pour something", subtitle: "Optional. We'll remember.")
                Button {
                    HapticsService.shared.tap()
                    vm.phase = .lighting
                } label: {
                    FTCard {
                        HStack {
                            Image(systemName: "drop.degreesign")
                            Text("Skip the drink").font(FTType.body(15, weight: .medium))
                            Spacer()
                        }
                    }
                }.buttonStyle(.plain)

                ForEach(drinks) { drink in
                    Button {
                        HapticsService.shared.tap()
                        vm.selectDrink(drink)
                    } label: {
                        FTCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drink.category.uppercased())
                                        .font(FTType.caption(11, weight: .semibold))
                                        .foregroundStyle(FTColor.inkMuted)
                                    Text(drink.name).font(FTType.body(16, weight: .medium))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                            }
                        }
                    }.buttonStyle(.plain)
                }

                methodPicker(vm: vm)
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.bottom, FTSpace.xxxl)
        }
    }

    private func methodPicker(vm: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("How will you light it?")
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .textCase(.uppercase)
                .padding(.top, FTSpace.lg)
            HStack(spacing: FTSpace.sm) {
                ForEach(Session.LightingMethod.allCases, id: \.self) { method in
                    Button {
                        HapticsService.shared.tap()
                        vm.lightingMethod = method
                    } label: {
                        Text(method.displayName)
                            .font(FTType.caption(12, weight: .medium))
                            .padding(.horizontal, FTSpace.md)
                            .padding(.vertical, FTSpace.sm)
                            .background(vm.lightingMethod == method ? FTColor.gold : FTColor.surface)
                            .foregroundStyle(vm.lightingMethod == method ? FTColor.inkInverse : FTColor.ink)
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func pickerHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FTType.display(28)).foregroundStyle(FTColor.gold)
            Text(subtitle).font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
        }
        .padding(.top, FTSpace.lg)
    }
}

private struct ActiveSessionView: View {
    @Bindable var vm: SessionViewModel

    var body: some View {
        VStack(spacing: FTSpace.lg) {
            if let s = vm.session {
                BurnTimerView(session: s)
                    .padding(.horizontal, FTSpace.lg)
            }
            if let cigar = vm.cigar {
                VStack(spacing: 2) {
                    Text(cigar.brand.uppercased())
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted)
                    Text(cigar.line).font(FTType.heading(20))
                }
            }
            Spacer()
            FTButton(title: "End session", style: .ghost) {
                Task { await vm.endSession() }
            }
            .padding(.horizontal, FTSpace.xl)
        }
        .padding(.top, FTSpace.xxl)
    }
}
