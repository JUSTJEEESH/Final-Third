import SwiftUI

/// Full session entry flow:
///   1. Pick cigar
///   2. Pick drink (optional, with skip)
///   3. Pick lighting method (rich cards, dedicated step)
///   4. Lighting Ceremony
///   5. Active session with burn timer
///   6. Summary
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
        case .selectingCigar:           CigarPicker(vm: vm, cigars: cigars)
        case .selectingDrink:           DrinkPicker(vm: vm, drinks: drinks)
        case .selectingLightingMethod:  MethodPicker(vm: vm)
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
        case .active:                   ActiveSessionView(vm: vm)
        case .summary:                  SessionSummaryView(vm: vm)
        case .finished:                 Color.clear.onAppear { dismiss() }
        }
    }

    private func loadCatalog() async {
        async let cigarsTask = (try? await cigarRepo.search(.init(), limit: 200)) ?? []
        async let drinksTask = (try? await drinkRepo.list(category: nil)) ?? []
        cigars = await cigarsTask
        drinks = await drinksTask
    }
}

// MARK: - Cigar picker

private struct CigarPicker: View {
    @Bindable var vm: SessionViewModel
    let cigars: [Cigar]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                PickerHeader(eyebrow: "Step 1",
                             title: "Pick your cigar.",
                             subtitle: "Choose tonight's company.")
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
                                        .foregroundStyle(FTColor.gold)
                                        .tracking(1.4)
                                    Text(cigar.line).font(FTType.body(16, weight: .medium))
                                    if let v = cigar.vitola {
                                        Text(v).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                                    }
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
}

// MARK: - Drink picker

private struct DrinkPicker: View {
    @Bindable var vm: SessionViewModel
    let drinks: [Drink]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                PickerHeader(eyebrow: "Step 2",
                             title: "Pour something.",
                             subtitle: "Optional. We'll remember.")
                Button {
                    HapticsService.shared.tap()
                    vm.skipDrink()
                } label: {
                    FTCard {
                        HStack {
                            Image(systemName: "drop.degreesign")
                            Text("Skip the drink").font(FTType.body(15, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
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
                                        .foregroundStyle(FTColor.gold)
                                        .tracking(1.4)
                                    Text(drink.name).font(FTType.body(16, weight: .medium))
                                    if let s = drink.subtype {
                                        Text(s).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                                    }
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
}

// MARK: - Lighting method picker (dedicated step, rich cards)

private struct MethodPicker: View {
    @Bindable var vm: SessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                PickerHeader(eyebrow: "Step 3",
                             title: "How will you light it?",
                             subtitle: "Each method changes the ceremony.")

                ForEach(Session.LightingMethod.allCases, id: \.self) { method in
                    MethodCard(method: method, isSelected: vm.lightingMethod == method) {
                        HapticsService.shared.tap()
                        vm.chooseLightingMethod(method)
                    }
                }
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.bottom, FTSpace.xxxl)
        }
    }
}

private struct MethodCard: View {
    let method: Session.LightingMethod
    let isSelected: Bool
    let action: () -> Void

    private var style: FlameStyle { FlameStyle.forMethod(method) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: FTSpace.lg) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [style.haloColor, .clear],
                            center: .center, startRadius: 0, endRadius: 38
                        ))
                        .frame(width: 76, height: 76)
                    Image(systemName: style.toolSymbol)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [style.coreColor, style.bodyColor, style.outerColor],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.toolName)
                        .font(FTType.heading(18, weight: .semibold))
                        .foregroundStyle(FTColor.ink)
                    Text(style.methodCopy)
                        .font(FTType.caption(12))
                        .foregroundStyle(FTColor.inkMuted)
                    Text(durationCopy)
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkFaint)
                        .tracking(1.2)
                        .padding(.top, 2)
                }
                Spacer()
                Image(systemName: isSelected ? "chevron.right.circle.fill" : "chevron.right")
                    .foregroundStyle(isSelected ? FTColor.gold : FTColor.inkFaint)
            }
            .padding(FTSpace.lg)
            .background(FTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(isSelected ? FTColor.gold : FTColor.divider,
                            lineWidth: isSelected ? 1.5 : FTStroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    private var durationCopy: String {
        switch method {
        case .torch: return "FAST"
        case .softFlame: return "EVERYDAY"
        case .match: return "TRADITIONAL"
        case .cedar: return "SLOW · CONNOISSEUR"
        }
    }
}

// MARK: - Header

private struct PickerHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(eyebrow.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(FTColor.gold)
            Text(title).font(FTType.display(28)).foregroundStyle(FTColor.ink)
            Text(subtitle).font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
        }
        .padding(.top, FTSpace.xl)
    }
}

// MARK: - Active session

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
