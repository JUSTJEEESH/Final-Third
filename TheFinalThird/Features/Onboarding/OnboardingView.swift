import SwiftUI

struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: OnboardingViewModel?

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            backgroundGlow
            if let vm {
                content(vm: vm)
            } else {
                FTLoadingView(label: "Pouring a drink…")
            }
        }
        .task {
            if vm == nil, case .signedIn(let userID) = container.auth.state {
                vm = OnboardingViewModel(
                    userID: userID,
                    emailFromSession: nil,
                    presetDisplayName: nil,
                    notifications: container.notifications,
                    onComplete: { [weak container] in
                        container?.markOnboardingComplete()
                    }
                )
                await vm?.loadCatalog()
            }
        }
    }

    private var backgroundGlow: some View {
        RadialGradient(
            colors: [FTColor.gold.opacity(0.10), .clear],
            center: .top, startRadius: 0, endRadius: 380
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func content(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            stepIndicator(current: vm.step.rawValue, total: OnboardingViewModel.Step.allCases.count)
                .padding(.top, FTSpace.xl)
                .padding(.bottom, FTSpace.lg)

            ScrollView {
                Group {
                    switch vm.step {
                    case .name: NameStep(vm: vm)
                    case .location: LocationStep(vm: vm)
                    case .usual: UsualStep(vm: vm)
                    case .vibe: VibeStep(vm: vm)
                    case .ready: ReadyStep(vm: vm)
                    }
                }
                .padding(.horizontal, FTSpace.xl)
                .padding(.bottom, FTSpace.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(vm.step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .animation(FTMotion.easeOutSoft, value: vm.step)

            navigationBar(vm: vm)
        }
    }

    private func stepIndicator(current: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0 ..< total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? FTColor.gold : FTColor.divider)
                    .frame(width: i == current ? 24 : 10, height: 4)
                    .animation(FTMotion.easeOutSoft, value: current)
            }
        }
    }

    @ViewBuilder
    private func navigationBar(vm: OnboardingViewModel) -> some View {
        VStack(spacing: FTSpace.sm) {
            if let error = vm.error {
                Text(error)
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpace.xl)
            }

            HStack(spacing: FTSpace.sm) {
                if vm.canGoBack {
                    Button { vm.back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                            .frame(width: 52, height: 52)
                            .background(FTColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                                    .stroke(FTColor.divider, lineWidth: FTStroke.thin)
                            )
                    }
                    .accessibilityLabel("Back")
                }

                if vm.step == .ready {
                    FTButton(title: "Take my chair", style: .gold, isLoading: vm.isSaving) {
                        Task { await vm.save() }
                    }
                } else {
                    FTButton(title: "Continue", style: .gold) { vm.next() }
                        .opacity(vm.canContinue ? 1 : 0.4)
                        .disabled(!vm.canContinue)
                }
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.bottom, FTSpace.xl)
            .padding(.top, FTSpace.sm)
        }
    }
}

// MARK: - Step views

private struct StepHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(eyebrow.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.gold)
                .tracking(2)
            Text(title)
                .font(FTType.display(32))
                .foregroundStyle(FTColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(FTType.body(15))
                .foregroundStyle(FTColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, FTSpace.xl)
    }
}

private struct NameStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "01 — your name",
                title: "What should we call you?",
                subtitle: "Use whatever feels right. You can change it later."
            )
            FTField(title: "Name or handle", text: $vm.displayName,
                    placeholder: "Marcus", autocap: .words)
            FTField(title: "@handle (optional)", text: $vm.handle,
                    placeholder: "marcus", autocap: .never)
            FTField(title: "Bio (optional)", text: $vm.bio,
                    placeholder: "What's your story?", autocap: .sentences, axis: .vertical)
        }
    }
}

private struct LocationStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "02 — where you smoke",
                title: "Where's your chair?",
                subtitle: "Helps us surface nearby people, events, and drops."
            )
            FTField(title: "City (optional)", text: $vm.city,
                    placeholder: "Tegucigalpa", autocap: .words)
            FTCard {
                Toggle(isOn: $vm.isHondurasLocal) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Honduras local")
                            .font(FTType.body(15, weight: .medium))
                        Text("We'll surface nearby events and locals.")
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                }
                .tint(FTColor.gold)
            }
        }
    }
}

private struct UsualStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "03 — your ritual",
                title: "When do you settle in?",
                subtitle: "We'll quietly remind you. Your chair is ready."
            )

            FTCard {
                Toggle("Send me a reminder", isOn: $vm.enableUsualReminder)
                    .tint(FTColor.gold)
            }

            if vm.enableUsualReminder {
                FTCard {
                    DatePicker("",
                               selection: $vm.preferredTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
            }

            sectionTitle("Default cigar")
            cigarPicker
            sectionTitle("Default drink")
            drinkPicker
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(FTType.caption(11, weight: .semibold))
            .foregroundStyle(FTColor.inkMuted)
            .tracking(1.2)
            .padding(.top, FTSpace.sm)
    }

    private var cigarPicker: some View {
        Menu {
            Button("None for now") { vm.cigar = nil }
            ForEach(vm.cigars) { c in
                Button(c.displayName) { vm.cigar = c }
            }
        } label: {
            FTCard {
                HStack {
                    Text(vm.cigar?.displayName ?? "Choose a cigar")
                        .font(FTType.body(15))
                        .foregroundStyle(vm.cigar == nil ? FTColor.inkMuted : FTColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
    }

    private var drinkPicker: some View {
        Menu {
            Button("None for now") { vm.drink = nil }
            ForEach(vm.drinks) { d in
                Button(d.name) { vm.drink = d }
            }
        } label: {
            FTCard {
                HStack {
                    Text(vm.drink?.name ?? "Choose a drink")
                        .font(FTType.body(15))
                        .foregroundStyle(vm.drink == nil ? FTColor.inkMuted : FTColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
    }
}

private struct VibeStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "04 — the vibe",
                title: "Set the room.",
                subtitle: "Your default ambient mix and how you show up."
            )

            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text("AMBIENCE")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1.2)
                ForEach(AudioTheme.allCases, id: \.self) { theme in
                    Button { vm.audioTheme = theme; HapticsService.shared.soft() } label: {
                        FTCard {
                            HStack {
                                Image(systemName: vm.audioTheme == theme ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(vm.audioTheme == theme ? FTColor.gold : FTColor.inkFaint)
                                Text(theme.displayName)
                                    .font(FTType.body(15))
                                    .foregroundStyle(FTColor.ink)
                                Spacer()
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text("PRIVACY")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1.2)
                FTCard {
                    Toggle(isOn: $vm.ghostModeDefault) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ghost by default")
                                .font(FTType.body(15, weight: .medium))
                            Text("Step in invisibly. No notifications fire on arrival.")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
                    .tint(FTColor.gold)
                }
                FTCard {
                    Toggle(isOn: $vm.voiceEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow voice rooms")
                                .font(FTType.body(15, weight: .medium))
                            Text("You're always muted by default. Hold to talk.")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
                    .tint(FTColor.gold)
                }
            }
        }
    }
}

private struct ReadyStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "05 — your chair",
                title: "Your chair is ready.",
                subtitle: "Take a breath. Step in."
            )

            FTCard(elevated: true) {
                VStack(alignment: .leading, spacing: FTSpace.sm) {
                    Text("PROFILE")
                        .font(FTType.caption(10, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted)
                        .tracking(1.4)
                    Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                        .font(FTType.heading(20))
                    if !vm.handle.isEmpty {
                        Text("@\(vm.handle)")
                            .font(FTType.caption(12))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                    if !vm.city.isEmpty {
                        Text(vm.city)
                            .font(FTType.caption(12))
                            .foregroundStyle(FTColor.inkFaint)
                    }
                }
            }

            FTCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE USUAL")
                        .font(FTType.caption(10, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted)
                        .tracking(1.4)
                    Text(timeString)
                        .font(FTType.body(15, weight: .medium))
                    if let cigar = vm.cigar {
                        Text(cigar.displayName)
                            .font(FTType.caption(12))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                    if let drink = vm.drink {
                        Text(drink.name)
                            .font(FTType.caption(12))
                            .foregroundStyle(FTColor.inkFaint)
                    }
                }
            }

            FTCard {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(FTColor.gold)
                    Text(vm.audioTheme.displayName)
                        .font(FTType.body(14))
                    Spacer()
                    if vm.ghostModeDefault {
                        Text("ghost")
                            .font(FTType.caption(10, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(FTColor.surfaceHi)
                            .clipShape(Capsule())
                            .foregroundStyle(FTColor.inkMuted)
                    }
                }
            }
        }
    }

    private var timeString: String {
        vm.preferredTime.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Field

private struct FTField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var autocap: TextInputAutocapitalization = .sentences
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.xs) {
            Text(title.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .tracking(1)
            TextField("", text: $text,
                      prompt: Text(placeholder).foregroundColor(FTColor.inkFaint),
                      axis: axis)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(autocap == .never)
                .padding(FTSpace.md)
                .background(FTColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.md)
                        .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
                .foregroundStyle(FTColor.ink)
        }
    }
}
