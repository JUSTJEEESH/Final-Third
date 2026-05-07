import SwiftUI

/// The world-class onboarding flow.
///
/// 9 logical screens grouped into three phases:
///   • Welcome — sets the tone with the brand and a single CTA.
///   • Intro — three-card paged carousel selling the value (the place,
///     the ritual, the journal).
///   • Setup — name → avatar → location → usual → vibe → reminders →
///     ready. Progress dots only show during this phase.
///
/// The whole flow lives inside a single dark themed surface with
/// leather grain. Each step has its own atmosphere — flame for the
/// welcome and ritual cards, paper for the journal card, gold accents
/// throughout. Transitions are paged with opacity blends so the user
/// feels like they're being eased into the room.
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: OnboardingViewModel?
    @State private var showAvatarPicker = false

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            TexturePanel(texture: .leather, opacity: 0.10, zoom: 1.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // Warm overhead glow — same lamp as the rest of the app.
            RadialGradient(
                colors: [FTColor.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            if let vm {
                content(vm: vm)
                    .sheet(isPresented: $showAvatarPicker) {
                        AvatarPickerView(userID: vm.userID) { url in
                            vm.avatarURL = url
                        }
                    }
            } else {
                FTLoadingView(label: "Setting your chair…")
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

    @ViewBuilder
    private func content(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 0) {
            // Step indicator only shows during the setup phase.
            if let setupIndex = vm.step.setupIndex {
                stepIndicator(current: setupIndex,
                              total: OnboardingViewModel.Step.setupCount)
                    .padding(.top, FTSpace.xl)
                    .padding(.bottom, FTSpace.lg)
            } else {
                Spacer().frame(height: FTSpace.xxxl)
            }

            ScrollView {
                Group {
                    switch vm.step {
                    case .welcome: WelcomeStep(vm: vm)
                    case .intro: IntroStep(vm: vm)
                    case .name: NameStep(vm: vm)
                    case .avatar: AvatarStep(vm: vm,
                                             showPicker: { showAvatarPicker = true })
                    case .location: LocationStep(vm: vm)
                    case .usual: UsualStep(vm: vm)
                    case .vibe: VibeStep(vm: vm)
                    case .notifications: NotificationsStep(vm: vm)
                    case .ready: ReadyStep(vm: vm)
                    }
                }
                .padding(.horizontal, FTSpace.xl)
                .padding(.bottom, FTSpace.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(vm.step.rawValue * 10 + vm.introIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .animation(FTMotion.easeOutSoft, value: vm.step)
            .animation(FTMotion.easeOutSoft, value: vm.introIndex)

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

                primaryButton(vm: vm)
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.top, FTSpace.sm)

            if vm.step == .avatar {
                Button("Skip for now") { vm.next() }
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.inkFaint)
                    .padding(.bottom, 4)
            } else if vm.step == .notifications && !vm.didRequestNotifications {
                Button("Maybe later") { vm.next() }
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.inkFaint)
                    .padding(.bottom, 4)
            }

            // Always-on escape hatch. If the session is broken (e.g. the
            // auth user was deleted server-side) the save will fail and
            // the user needs a way out.
            Button {
                Task { await container.auth.signOut() }
            } label: {
                Text("Not you? Sign out")
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.inkFaint)
            }
            .padding(.bottom, FTSpace.xl)
        }
    }

    @ViewBuilder
    private func primaryButton(vm: OnboardingViewModel) -> some View {
        switch vm.step {
        case .welcome:
            FTButton(title: "Let me see", style: .gold) { vm.next() }
        case .intro:
            FTButton(
                title: vm.introIndex < vm.introCount - 1 ? "Continue" : "I'm in",
                style: .gold
            ) { vm.next() }
        case .ready:
            FTButton(title: "Take my chair", style: .gold, isLoading: vm.isSaving) {
                Task { await vm.save() }
            }
        case .notifications:
            FTButton(
                title: vm.didRequestNotifications ? "Continue" : "Turn on reminders",
                style: .gold
            ) {
                if vm.didRequestNotifications {
                    vm.next()
                } else {
                    Task {
                        await vm.requestNotificationPermission()
                    }
                }
            }
        default:
            FTButton(title: "Continue", style: .gold) { vm.next() }
                .opacity(vm.canContinue ? 1 : 0.4)
                .disabled(!vm.canContinue)
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

// MARK: Welcome

private struct WelcomeStep: View {
    @Bindable var vm: OnboardingViewModel
    @State private var glow = false

    var body: some View {
        VStack(spacing: FTSpace.xxl) {
            Spacer().frame(height: FTSpace.xxl)

            // Hero flame — gold gradient with breathing glow.
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [FTColor.gold.opacity(glow ? 0.55 : 0.30), .clear],
                        center: .center, startRadius: 4,
                        endRadius: glow ? 110 : 80
                    ))
                    .frame(width: 240, height: 240)
                    .animation(FTMotion.breatheCurve, value: glow)
                Image(systemName: "flame.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(LinearGradient(
                        colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: FTColor.ember.opacity(0.7), radius: 20, x: 0, y: 0)
            }
            .onAppear { glow = true }

            VStack(spacing: FTSpace.md) {
                Text("THE FINAL THIRD")
                    .font(FTType.caption(11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(FTColor.gold)
                Text("Pour a drink.\nLight a cigar.\nWe've saved your chair.")
                    .font(FTType.display(28, weight: .semibold))
                    .foregroundStyle(FTColor.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, FTSpace.xxl)
    }
}

// MARK: Intro carousel

private struct IntroStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack {
            Spacer().frame(height: FTSpace.xxl)
            switch vm.introIndex {
            case 0: introCard(
                eyebrow: "01 — A PLACE",
                title: "Not a feed. A place.",
                copy: "When you light up, your people are already there. Quiet voices. Real presence. No content scroll.",
                visual: { PresenceIllustration() }
            )
            case 1: introCard(
                eyebrow: "02 — A RITUAL",
                title: "Every cigar deserves an entrance.",
                copy: "Match. Torch. Cedar spill. Soft flame. The lighting ceremony slows you down before you sit down.",
                visual: { RitualIllustration() }
            )
            default: introCard(
                eyebrow: "03 — A JOURNAL",
                title: "A library of your nights.",
                copy: "Every cigar lit, every drink poured, every night that helped you unwind — saved. So you remember.",
                visual: { JournalIllustration() }
            )
            }

            // Carousel dots
            HStack(spacing: 8) {
                ForEach(0 ..< vm.introCount, id: \.self) { i in
                    Circle()
                        .fill(i == vm.introIndex ? FTColor.gold : FTColor.divider)
                        .frame(width: 7, height: 7)
                        .animation(FTMotion.easeOutSoft, value: vm.introIndex)
                }
            }
            .padding(.top, FTSpace.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, FTSpace.xxl)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 {
                        if vm.introIndex < vm.introCount - 1 {
                            vm.introIndex += 1
                            HapticsService.shared.soft()
                        }
                    } else if value.translation.width > 50 {
                        if vm.introIndex > 0 {
                            vm.introIndex -= 1
                            HapticsService.shared.soft()
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func introCard<V: View>(
        eyebrow: String,
        title: String,
        copy: String,
        @ViewBuilder visual: () -> V
    ) -> some View {
        VStack(spacing: FTSpace.xl) {
            visual()
                .frame(height: 200)
            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text(eyebrow)
                    .font(FTType.caption(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(FTColor.gold)
                Text(title)
                    .font(FTType.display(28, weight: .semibold))
                    .foregroundStyle(FTColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy)
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(.horizontal, FTSpace.lg)
        }
    }
}

private struct PresenceIllustration: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [FTColor.gold.opacity(0.15), .clear],
                    center: .center, startRadius: 4, endRadius: 130
                ))
                .frame(width: 280, height: 280)
            // Three overlapping presence rings
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .stroke(FTColor.gold.opacity(0.55 - Double(i) * 0.12), lineWidth: 1)
                    .frame(width: 70, height: 70)
                    .offset(
                        x: [-50, 0, 50][i],
                        y: phase ? CGFloat(i - 1) * 4 : 0
                    )
            }
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .fill(FTColor.surface)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: ["person.fill", "person.2.fill", "person.fill"][i])
                            .foregroundStyle(FTColor.gold.opacity(0.7))
                            .font(.system(size: 22))
                    )
                    .offset(
                        x: [-50, 0, 50][i],
                        y: phase ? CGFloat(i - 1) * 4 : 0
                    )
            }
        }
        .animation(FTMotion.breatheCurve, value: phase)
        .onAppear { phase = true }
    }
}

private struct RitualIllustration: View {
    @State private var live = false
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [FTColor.ember.opacity(0.35), .clear],
                    center: .center, startRadius: 4, endRadius: 130
                ))
                .frame(width: 280, height: 280)
            Image(systemName: "flame.fill")
                .font(.system(size: 96, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                    startPoint: .top, endPoint: .bottom
                ))
                .shadow(color: FTColor.ember.opacity(0.7), radius: 18, x: 0, y: 0)
                .scaleEffect(live ? 1.05 : 0.95)
                .animation(FTMotion.breatheCurve, value: live)
        }
        .onAppear { live = true }
    }
}

private struct JournalIllustration: View {
    var body: some View {
        ZStack {
            // Aged-paper card behind a "book" suggestion.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FTColor.surfaceHi)
                .frame(width: 180, height: 220)
                .overlay(
                    TexturePanel(texture: .agedPaper, opacity: 0.30, zoom: 1.4)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FTColor.divider, lineWidth: FTStroke.thin)
                )
                .rotationEffect(.degrees(-3))
                .offset(x: -16, y: 6)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FTColor.surface)
                .frame(width: 180, height: 220)
                .overlay(
                    TexturePanel(texture: .leather, opacity: 0.35, zoom: 1.4)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
                .overlay(
                    VStack(spacing: FTSpace.sm) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(FTColor.gold)
                        Text("YOUR NIGHTS")
                            .font(FTType.caption(9, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(FTColor.gold.opacity(0.8))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(FTColor.gold.opacity(0.4), lineWidth: 0.5)
                )
                .rotationEffect(.degrees(2))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 6)
        }
    }
}

// MARK: Setup steps

private struct NameStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Your name",
                title: "What should we call you?",
                subtitle: "Use whatever feels right. You can change it later."
            )
            FTField(title: "Name or handle", text: $vm.displayName,
                    placeholder: "Marcus", autocap: .words)
            FTField(title: "@handle (optional)", text: $vm.handle,
                    placeholder: "marcus", autocap: .never, disableAutocorrect: true)
            FTField(title: "Bio (optional)", text: $vm.bio,
                    placeholder: "What's your story?", autocap: .sentences, axis: .vertical)
        }
    }
}

private struct AvatarStep: View {
    @Bindable var vm: OnboardingViewModel
    let showPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Your face",
                title: "A photo, if you'd like.",
                subtitle: "Helps your people recognize you across the lounge. You can add it later."
            )

            VStack(spacing: FTSpace.md) {
                Button(action: showPicker) {
                    ZStack {
                        Circle().fill(FTColor.surface)
                        if let url = vm.avatarURL {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    placeholder
                                }
                            }
                        } else {
                            placeholder
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(FTColor.gold.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: FTColor.goldGlow.opacity(0.5), radius: 24, x: 0, y: 0)
                }
                .buttonStyle(.plain)

                Button {
                    HapticsService.shared.tap()
                    showPicker()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.avatarURL == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                        Text(vm.avatarURL == nil ? "Add a photo" : "Change photo")
                            .font(FTType.body(15, weight: .medium))
                    }
                    .foregroundStyle(FTColor.gold)
                    .padding(.horizontal, FTSpace.lg)
                    .padding(.vertical, FTSpace.md)
                    .background(FTColor.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(FTColor.gold.opacity(0.4), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, FTSpace.lg)
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 64))
            .foregroundStyle(FTColor.inkFaint)
    }
}

private struct LocationStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Where you sit",
                title: "Where's your chair?",
                subtitle: "Helps us surface nearby people, events, and drops. Optional."
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
                eyebrow: "Your ritual",
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
                eyebrow: "The vibe",
                title: "Set the room.",
                subtitle: "Your default ambient mix and how you show up."
            )

            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text("AMBIENCE")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1.2)
                ForEach(AudioTheme.allCases, id: \.self) { theme in
                    Button {
                        vm.audioTheme = theme
                        HapticsService.shared.soft()
                    } label: {
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

private struct NotificationsStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Stay in touch",
                title: "Your chair is ready.",
                subtitle: "We'll send a single quiet ping at your usual time. Nothing more, nothing else."
            )

            FTCard(elevated: true) {
                VStack(alignment: .leading, spacing: FTSpace.md) {
                    HStack(spacing: FTSpace.md) {
                        ZStack {
                            Circle()
                                .stroke(FTColor.gold.opacity(0.5), lineWidth: 1)
                                .frame(width: 48, height: 48)
                            Image(systemName: "bell.fill")
                                .foregroundStyle(FTColor.gold)
                                .font(.system(size: 20, weight: .medium))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ARRIVAL SIGNAL")
                                .font(FTType.caption(10, weight: .semibold))
                                .foregroundStyle(FTColor.gold)
                                .tracking(1.4)
                            Text("Subtle. Once a night. Easy to silence.")
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
                    if vm.didRequestNotifications {
                        HStack(spacing: 6) {
                            Image(systemName: vm.notificationsGranted ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(vm.notificationsGranted ? FTColor.gold : FTColor.inkMuted)
                            Text(vm.notificationsGranted ? "Reminders are on." : "Off for now — you can flip this in Settings later.")
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
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
                eyebrow: "Your chair",
                title: "Take your seat.",
                subtitle: "Take a breath. Step in."
            )

            FTCard(elevated: true) {
                HStack(spacing: FTSpace.md) {
                    if let url = vm.avatarURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Circle().fill(FTColor.surfaceHi)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(FTColor.gold.opacity(0.5), lineWidth: 1))
                    } else {
                        ZStack {
                            Circle().fill(FTColor.surfaceHi)
                            Text(initials)
                                .font(FTType.caption(15, weight: .semibold))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(FTColor.gold.opacity(0.5), lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROFILE")
                            .font(FTType.caption(10, weight: .semibold))
                            .foregroundStyle(FTColor.gold)
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
                    Spacer()
                }
            }

            FTCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE USUAL")
                        .font(FTType.caption(10, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
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
                HStack(spacing: FTSpace.sm) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(FTColor.gold)
                    Text(vm.audioTheme.displayName)
                        .font(FTType.body(14))
                    Spacer()
                    if vm.ghostModeDefault {
                        chip("ghost")
                    }
                    if vm.voiceEnabled {
                        chip("voice")
                    }
                    if vm.didRequestNotifications && vm.notificationsGranted {
                        chip("reminders")
                    }
                }
            }
        }
    }

    private var timeString: String {
        vm.preferredTime.formatted(date: .omitted, time: .shortened)
    }

    private var initials: String {
        let parts = vm.displayName.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined()
        return s.isEmpty ? "··" : s.uppercased()
    }

    private func chip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(FTType.caption(9, weight: .semibold))
            .tracking(1.2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(FTColor.surfaceHi)
            .clipShape(Capsule())
            .foregroundStyle(FTColor.inkMuted)
    }
}

// MARK: - Field

private struct FTField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var autocap: TextInputAutocapitalization = .sentences
    var disableAutocorrect: Bool = false
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
                .autocorrectionDisabled(disableAutocorrect)
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
