import SwiftUI

/// Full session entry flow:
///   1. Pick cigar
///   2. Pick drink (optional, with skip)
///   3. Pick lighting method (rich cards, dedicated step)
///   4. Lighting Ceremony
///   5. Active session with burn timer
///   6. Summary
///
/// The view-model lives on `AppContainer.session` so other surfaces
/// (Lounge / Room / persistent session bar) can observe what's burning
/// without coordinating through this view. The view itself is now a
/// thin presenter over `container.session.current` — it does not own
/// the session lifecycle.
struct SessionFlowView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var cigars: [Cigar] = []
    @State private var drinks: [Drink] = []
    @State private var showCancelConfirm = false

    private let cigarRepo: CigarRepository = LiveCigarRepository()
    private let drinkRepo: DrinkRepository = LiveDrinkRepository()

    /// Source-of-truth view-model. Created by the caller via
    /// `container.session.beginFlow(...)` before this view appears, so
    /// `current` should always be non-nil while we're on screen.
    private var vm: SessionViewModel? { container.session.current }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FTColor.background.ignoresSafeArea()
            TexturePanel(texture: .leather, opacity: 0.08, zoom: 1.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            if let vm { phase(vm) } else { ProgressView().tint(FTColor.gold) }

            // Cancel button — shows on the picker steps and the ceremony.
            // During the active session it's hidden because we have a
            // proper End Session affordance with its own confirmation.
            if let vm, showsCancel(for: vm.phase) {
                cancelButton(vm: vm)
                    .padding(.top, FTSpace.md)
                    .padding(.leading, FTSpace.lg)
            }
        }
        .task { await loadCatalog() }
        .alert("Cancel and step out?", isPresented: $showCancelConfirm) {
            Button("Stay", role: .cancel) {}
            Button("Step out", role: .destructive) {
                container.session.clear()
                dismiss()
            }
        } message: {
            Text("Your selections won't be saved.")
        }
    }

    private func showsCancel(for phase: SessionViewModel.Phase) -> Bool {
        switch phase {
        case .selectingCigar, .selectingDrink, .selectingLightingMethod, .lighting:
            return true
        case .active, .summary, .finished:
            return false
        }
    }

    private func cancelButton(vm: SessionViewModel) -> some View {
        Button {
            HapticsService.shared.tap()
            // Cigar picker — no selection yet, just dismiss.
            // Anywhere else — confirm.
            if vm.phase == .selectingCigar {
                dismiss()
            } else {
                showCancelConfirm = true
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FTColor.ink)
                .frame(width: 36, height: 36)
                .background(FTColor.surfaceHi.opacity(0.9))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
        }
        .accessibilityLabel("Cancel")
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
        case .finished:
            Color.clear.onAppear {
                container.session.clear()
                dismiss()
            }
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
    @State private var showEndConfirm = false

    var body: some View {
        ZStack {
            // Atmospheric background — warm overhead glow seeping in
            // from the top, leather grain underneath the ceremony space.
            FTColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [FTColor.ember.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: FTSpace.lg) {
                Text("IN SESSION")
                    .font(FTType.caption(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(FTColor.gold)
                    .padding(.top, FTSpace.xxl)

                // Cigar identity — display title, subtle vitola.
                if let cigar = vm.cigar {
                    VStack(spacing: 4) {
                        Text(cigar.brand.uppercased())
                            .font(FTType.caption(11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(FTColor.gold.opacity(0.85))
                        Text(cigar.line)
                            .font(FTType.display(28, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, FTSpace.xl)
                        if let v = cigar.vitola {
                            Text(v)
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
                }

                // Burn timer ring — the centerpiece.
                if let s = vm.session {
                    BurnTimerView(session: s)
                        .padding(.horizontal, FTSpace.xxl)
                        .padding(.vertical, FTSpace.md)
                }

                // Pairing chips — drink + lighting method, gold-bordered.
                HStack(spacing: FTSpace.sm) {
                    chip(icon: "flame.fill", text: vm.lightingMethod.displayName,
                         tint: FTColor.gold)
                    if let drink = vm.drink {
                        chip(icon: "wineglass", text: drink.name, tint: FTColor.inkMuted)
                    }
                }

                Spacer()

                // End session — ghost style so it doesn't compete with
                // the cigar identity above. Confirmation alert prevents
                // accidental commits.
                FTButton(title: "End session", style: .ghost) {
                    HapticsService.shared.tap()
                    showEndConfirm = true
                }
                .padding(.horizontal, FTSpace.xl)
                .padding(.bottom, FTSpace.xl)
            }
        }
        .alert("End your session?", isPresented: $showEndConfirm) {
            Button("Keep going", role: .cancel) {}
            Button("End it") {
                Task { await vm.endSession() }
            }
        } message: {
            Text("We'll ask how it was, then it lands in your Journal.")
        }
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(FTType.caption(12, weight: .medium))
        }
        .foregroundStyle(tint == FTColor.gold ? FTColor.ink : tint)
        .padding(.horizontal, FTSpace.md)
        .padding(.vertical, FTSpace.sm)
        .background(FTColor.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                tint == FTColor.gold ? FTColor.gold.opacity(0.45) : FTColor.divider,
                lineWidth: FTStroke.hairline
            )
        )
    }
}
