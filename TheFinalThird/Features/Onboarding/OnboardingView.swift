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
                Spacer().frame(height: FTSpace.lg)
            }

            // Welcome and Intro are full-bleed presentational screens
            // that need real Spacers — wrapping them in a ScrollView
            // collapses the spacers and the user never sees the carousel.
            // Setup screens get a ScrollView so long forms can scroll.
            switch vm.step {
            case .welcome:
                WelcomeStep(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, FTSpace.xl)
                    .id(vm.step.rawValue)
                    .transition(stepTransition)
            case .intro:
                IntroStep(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, FTSpace.xl)
                    .id(vm.step.rawValue * 10 + vm.introIndex)
                    .transition(stepTransition)
            default:
                ScrollView {
                    Group {
                        switch vm.step {
                        case .name: NameStep(vm: vm)
                        case .avatar: AvatarStep(vm: vm,
                                                 showPicker: { showAvatarPicker = true })
                        case .location: LocationStep(vm: vm)
                        case .usual: UsualStep(vm: vm)
                        case .vibe: VibeStep(vm: vm)
                        case .notifications: NotificationsStep(vm: vm)
                        case .ready: ReadyStep(vm: vm)
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, FTSpace.xl)
                    .padding(.bottom, FTSpace.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(vm.step.rawValue)
                    .transition(stepTransition)
                }
            }

            navigationBar(vm: vm)
        }
        .animation(FTMotion.easeOutSoft, value: vm.step)
        .animation(FTMotion.easeOutSoft, value: vm.introIndex)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
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
            Spacer()

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
                Text("A quiet room for the last third of the day.\nFor the people who actually slow down.")
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, FTSpace.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
                subtitle: "However you'd introduce yourself across the table. First name, nickname, full name — whatever fits."
            )
            FTField(title: "Display name", text: $vm.displayName,
                    placeholder: "Marcus", autocap: .words)
            FTField(title: "@handle (optional)", text: $vm.handle,
                    placeholder: "marcus", autocap: .never, disableAutocorrect: true)
            FTField(title: "A line about you (optional)", text: $vm.bio,
                    placeholder: "Cuban purist. Old fashioneds. Late nights.",
                    autocap: .sentences, axis: .vertical)
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
                title: "Put a face to your name.",
                subtitle: "It's how regulars recognize each other across the lounge. No pressure — you can add one anytime from Settings."
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
    @State private var showCountryPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Where you sit",
                title: "Where's your chair?",
                subtitle: "We use this to surface nearby members, local events, and city-specific drops. Stays private — we never show your exact location."
            )

            VStack(alignment: .leading, spacing: FTSpace.xs) {
                Text("COUNTRY")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1)
                Button {
                    HapticsService.shared.tap()
                    showCountryPicker = true
                } label: {
                    FTCard {
                        HStack(spacing: FTSpace.md) {
                            Text(flagEmoji(for: vm.country) ?? "🌍")
                                .font(.system(size: 22))
                            Text(displayCountry)
                                .font(FTType.body(15))
                                .foregroundStyle(vm.country == nil ? FTColor.inkMuted : FTColor.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(FTColor.inkFaint)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            FTField(title: "City / area (optional)", text: $vm.city,
                    placeholder: cityPlaceholder, autocap: .words)

            FTCard {
                Toggle(isOn: $vm.isLocal) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I live here year-round")
                            .font(FTType.body(15, weight: .medium))
                        Text("Surfaces local lounges, hosts, and weeknight events instead of travel content.")
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                }
                .tint(FTColor.gold)
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selection: $vm.country)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var displayCountry: String {
        guard let code = vm.country else { return "Choose your country" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private var cityPlaceholder: String {
        guard let code = vm.country else { return "Roatán" }
        switch code {
        case "US": return "Brooklyn, NY"
        case "GB": return "London"
        case "JP": return "Tokyo"
        case "HN": return "Roatán"
        default: return ""
        }
    }

    private func flagEmoji(for code: String?) -> String? {
        guard let code, code.count == 2 else { return nil }
        let base: UInt32 = 127_397
        var s = ""
        for scalar in code.uppercased().unicodeScalars {
            if let v = UnicodeScalar(base + scalar.value) {
                s.unicodeScalars.append(v)
            }
        }
        return s
    }
}

private struct CountryPickerSheet: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    /// All ISO 3166-1 alpha-2 regions, sorted by their localized name in
    /// the current locale. Cached at first access.
    private static let allCountries: [(code: String, name: String)] = {
        Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }
            .compactMap { code -> (String, String)? in
                guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
                return (code, name)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }()

    private var filtered: [(code: String, name: String)] {
        guard !query.isEmpty else { return Self.allCountries }
        let q = query.lowercased()
        return Self.allCountries.filter {
            $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: FTSpace.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FTColor.inkFaint)
                        TextField("Search countries", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundStyle(FTColor.ink)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(FTColor.inkFaint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(FTSpace.md)
                    .background(FTColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                    .padding(.horizontal, FTSpace.xl)
                    .padding(.vertical, FTSpace.sm)

                    List {
                        ForEach(filtered, id: \.code) { item in
                            Button {
                                HapticsService.shared.tap()
                                selection = item.code
                                dismiss()
                            } label: {
                                HStack(spacing: FTSpace.md) {
                                    Text(flagEmoji(for: item.code) ?? "🌍")
                                        .font(.system(size: 20))
                                    Text(item.name)
                                        .font(FTType.body(15))
                                        .foregroundStyle(FTColor.ink)
                                    Spacer()
                                    if selection == item.code {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(FTColor.gold)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(FTColor.background)
                            .listRowSeparatorTint(FTColor.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.inkMuted)
                }
            }
        }
    }

    private func flagEmoji(for code: String) -> String? {
        guard code.count == 2 else { return nil }
        let base: UInt32 = 127_397
        var s = ""
        for scalar in code.uppercased().unicodeScalars {
            if let v = UnicodeScalar(base + scalar.value) {
                s.unicodeScalars.append(v)
            }
        }
        return s
    }
}

private struct UsualStep: View {
    @Bindable var vm: OnboardingViewModel
    @State private var showCigarPicker = false
    @State private var showDrinkPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "The usual",
                title: "What's your nightly ritual?",
                subtitle: "Tell us your go-to smoke and pour. We'll have it ready when you walk in — and remind you at the right hour, if you'd like."
            )

            FTCard {
                Toggle(isOn: $vm.enableUsualReminder) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet nightly reminder")
                            .font(FTType.body(15, weight: .medium))
                        Text("One soft ping at your time. Easy to silence.")
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                }
                .tint(FTColor.gold)
            }

            if vm.enableUsualReminder {
                VStack(alignment: .leading, spacing: FTSpace.xs) {
                    Text("WHAT TIME DO YOU SETTLE IN?")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted)
                        .tracking(1)
                    FTCard {
                        DatePicker("",
                                   selection: $vm.preferredTime,
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            VStack(alignment: .leading, spacing: FTSpace.xs) {
                Text("YOUR GO-TO CIGAR")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1)
                pickerButton(
                    icon: "flame.fill",
                    primary: vm.cigar?.displayName ?? "Pick a cigar",
                    secondary: vm.cigar?.country,
                    isSet: vm.cigar != nil
                ) {
                    HapticsService.shared.tap()
                    showCigarPicker = true
                }
                if vm.cigar != nil {
                    Button("Clear") { vm.cigar = nil }
                        .font(FTType.caption(12))
                        .foregroundStyle(FTColor.inkFaint)
                        .padding(.leading, 4)
                }
            }

            VStack(alignment: .leading, spacing: FTSpace.xs) {
                Text("YOUR GO-TO POUR")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1)
                pickerButton(
                    icon: "wineglass.fill",
                    primary: vm.drink?.name ?? "Pick a drink",
                    secondary: drinkSubtitle,
                    isSet: vm.drink != nil
                ) {
                    HapticsService.shared.tap()
                    showDrinkPicker = true
                }
                if vm.drink != nil {
                    Button("Clear") { vm.drink = nil }
                        .font(FTType.caption(12))
                        .foregroundStyle(FTColor.inkFaint)
                        .padding(.leading, 4)
                }
            }

            Text("You can leave these empty for now — we'll learn your taste as you log nights.")
                .font(FTType.caption(12))
                .foregroundStyle(FTColor.inkFaint)
                .padding(.top, FTSpace.xs)
        }
        .sheet(isPresented: $showCigarPicker) {
            CigarPickerSheet(cigars: vm.cigars, selection: $vm.cigar)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDrinkPicker) {
            DrinkPickerSheet(drinks: vm.drinks, selection: $vm.drink)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var drinkSubtitle: String? {
        guard let d = vm.drink else { return nil }
        return [d.brand, d.subtype].compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder
    private func pickerButton(
        icon: String,
        primary: String,
        secondary: String?,
        isSet: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            FTCard {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: icon)
                        .foregroundStyle(isSet ? FTColor.gold : FTColor.inkFaint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary)
                            .font(FTType.body(15, weight: isSet ? .medium : .regular))
                            .foregroundStyle(isSet ? FTColor.ink : FTColor.inkMuted)
                        if let secondary, !secondary.isEmpty {
                            Text(secondary)
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkFaint)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(FTColor.inkFaint)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CigarPickerSheet: View {
    let cigars: [Cigar]
    @Binding var selection: Cigar?
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [Cigar] {
        guard !query.isEmpty else { return cigars }
        let q = query.lowercased()
        return cigars.filter {
            $0.brand.lowercased().contains(q)
                || $0.line.lowercased().contains(q)
                || ($0.vitola?.lowercased().contains(q) ?? false)
                || ($0.country?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    List {
                        ForEach(filtered) { cigar in
                            Button {
                                HapticsService.shared.tap()
                                selection = cigar
                                dismiss()
                            } label: {
                                HStack(spacing: FTSpace.md) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(FTColor.gold.opacity(0.7))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cigar.displayName)
                                            .font(FTType.body(15, weight: .medium))
                                            .foregroundStyle(FTColor.ink)
                                        HStack(spacing: 6) {
                                            if let vitola = cigar.vitola {
                                                Text(vitola)
                                                    .font(FTType.caption(11))
                                                    .foregroundStyle(FTColor.inkMuted)
                                            }
                                            if let country = cigar.country {
                                                Text("·").foregroundStyle(FTColor.inkFaint)
                                                Text(country)
                                                    .font(FTType.caption(11))
                                                    .foregroundStyle(FTColor.inkFaint)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if selection?.id == cigar.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(FTColor.gold)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(FTColor.background)
                            .listRowSeparatorTint(FTColor.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose your cigar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.inkMuted)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: FTSpace.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FTColor.inkFaint)
            TextField("Brand, line, vitola, country", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .foregroundStyle(FTColor.ink)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FTColor.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FTSpace.md)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
        .padding(.horizontal, FTSpace.xl)
        .padding(.vertical, FTSpace.sm)
    }
}

private struct DrinkPickerSheet: View {
    let drinks: [Drink]
    @Binding var selection: Drink?
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var category: String?

    private var categories: [String] {
        let set = Set(drinks.map(\.category))
        return Array(set).sorted()
    }

    private var filtered: [Drink] {
        var list = drinks
        if let category {
            list = list.filter { $0.category == category }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q)
                    || ($0.brand?.lowercased().contains(q) ?? false)
                    || ($0.subtype?.lowercased().contains(q) ?? false)
                    || $0.category.lowercased().contains(q)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    if !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                categoryChip(label: "All", isSelected: category == nil) {
                                    category = nil
                                }
                                ForEach(categories, id: \.self) { c in
                                    categoryChip(label: c.capitalized, isSelected: category == c) {
                                        category = (category == c ? nil : c)
                                    }
                                }
                            }
                            .padding(.horizontal, FTSpace.xl)
                        }
                        .padding(.bottom, FTSpace.sm)
                    }
                    List {
                        ForEach(filtered) { drink in
                            Button {
                                HapticsService.shared.tap()
                                selection = drink
                                dismiss()
                            } label: {
                                HStack(spacing: FTSpace.md) {
                                    Image(systemName: "wineglass.fill")
                                        .foregroundStyle(FTColor.gold.opacity(0.7))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(drink.name)
                                            .font(FTType.body(15, weight: .medium))
                                            .foregroundStyle(FTColor.ink)
                                        HStack(spacing: 6) {
                                            if let brand = drink.brand {
                                                Text(brand)
                                                    .font(FTType.caption(11))
                                                    .foregroundStyle(FTColor.inkMuted)
                                                Text("·").foregroundStyle(FTColor.inkFaint)
                                            }
                                            Text(drink.subtype ?? drink.category.capitalized)
                                                .font(FTType.caption(11))
                                                .foregroundStyle(FTColor.inkFaint)
                                        }
                                    }
                                    Spacer()
                                    if selection?.id == drink.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(FTColor.gold)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(FTColor.background)
                            .listRowSeparatorTint(FTColor.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose your drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FTColor.inkMuted)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: FTSpace.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FTColor.inkFaint)
            TextField("Name, brand, style", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .foregroundStyle(FTColor.ink)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FTColor.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FTSpace.md)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
        .padding(.horizontal, FTSpace.xl)
        .padding(.vertical, FTSpace.sm)
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(FTType.caption(12, weight: .semibold))
                .foregroundStyle(isSelected ? FTColor.background : FTColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? FTColor.gold : FTColor.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? .clear : FTColor.divider,
                        lineWidth: FTStroke.thin
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct VibeStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "The vibe",
                title: "Set the room.",
                subtitle: "How the lounge sounds when you walk in, and how visible you want to be. Tweak any time."
            )

            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text("AMBIENCE")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .tracking(1.2)
                AmbiencePicker(selected: $vm.audioTheme)
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

/// Card-row audio theme picker. Reusable from Onboarding's vibe step.
/// Patron-only themes show a gold lock; tapping them presents the
/// PatronSheet rather than committing the selection.
private struct AmbiencePicker: View {
    @Environment(AppContainer.self) private var container
    @Binding var selected: AudioTheme
    @State private var showPatron = false

    var body: some View {
        VStack(spacing: FTSpace.sm) {
            ForEach(AudioTheme.allCases, id: \.self) { theme in
                let locked = theme.isPatron && !container.entitlements.isPremium
                Button {
                    if locked {
                        HapticsService.shared.tap()
                        showPatron = true
                    } else {
                        selected = theme
                        HapticsService.shared.soft()
                    }
                } label: {
                    FTCard {
                        HStack {
                            Image(systemName: selected == theme ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected == theme ? FTColor.gold : FTColor.inkFaint)
                            Text(theme.displayName)
                                .font(FTType.body(15))
                                .foregroundStyle(FTColor.ink)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(FTColor.gold.opacity(0.85))
                                    .font(.system(size: 11))
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPatron) {
            PatronSheet(trigger: "audio_theme_onboarding")
        }
    }
}

private struct NotificationsStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.lg) {
            StepHeader(
                eyebrow: "Last thing",
                title: "One quiet ping a night.",
                subtitle: "We'll tap you on the shoulder at your usual time — never spam, never marketing. You can turn it off in Settings any time."
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
                title: "Everything's ready.",
                subtitle: "One more breath. Then step inside."
            )

            // Identity card — avatar + name centered, location row beneath.
            FTCard(elevated: true) {
                VStack(spacing: FTSpace.md) {
                    avatar
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(FTColor.gold.opacity(0.6), lineWidth: 1))
                        .shadow(color: FTColor.goldGlow.opacity(0.4), radius: 18)

                    VStack(spacing: 4) {
                        Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                            .font(FTType.heading(22, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                        if !vm.handle.isEmpty {
                            Text("@\(vm.handle)")
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }

                    if hasLocation {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                                .foregroundStyle(FTColor.gold.opacity(0.8))
                            Text(locationLine)
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FTSpace.xs)
            }

            // Two-column summary: ritual on the left, vibe on the right.
            HStack(alignment: .top, spacing: FTSpace.sm) {
                summaryTile(
                    eyebrow: "RITUAL",
                    icon: "flame.fill",
                    primary: timeString,
                    lines: ritualLines
                )
                summaryTile(
                    eyebrow: "VIBE",
                    icon: "speaker.wave.2.fill",
                    primary: vm.audioTheme.displayName,
                    lines: vibeLines
                )
            }

            // Closing line — sets the tone before the CTA.
            Text("The door's open. Take your time.")
                .font(FTType.body(14))
                .foregroundStyle(FTColor.inkFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, FTSpace.xs)
                .italic()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = vm.avatarURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(FTColor.surfaceHi)
                }
            }
        } else {
            ZStack {
                Circle().fill(FTColor.surfaceHi)
                Text(initials)
                    .font(FTType.heading(24, weight: .semibold))
                    .foregroundStyle(FTColor.gold.opacity(0.8))
            }
        }
    }

    private func summaryTile(
        eyebrow: String,
        icon: String,
        primary: String,
        lines: [String]
    ) -> some View {
        FTCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(FTColor.gold)
                    Text(eyebrow)
                        .font(FTType.caption(10, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
                        .tracking(1.4)
                }
                Text(primary)
                    .font(FTType.body(15, weight: .medium))
                    .foregroundStyle(FTColor.ink)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(FTType.caption(11))
                        .foregroundStyle(FTColor.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timeString: String {
        vm.enableUsualReminder
            ? vm.preferredTime.formatted(date: .omitted, time: .shortened)
            : "Whenever"
    }

    private var ritualLines: [String] {
        var out: [String] = []
        if let cigar = vm.cigar { out.append(cigar.displayName) }
        if let drink = vm.drink { out.append(drink.name) }
        if out.isEmpty { out.append("We'll learn your taste") }
        return out
    }

    private var vibeLines: [String] {
        var out: [String] = []
        if vm.ghostModeDefault { out.append("Ghost by default") }
        if vm.voiceEnabled { out.append("Voice rooms enabled") }
        if vm.didRequestNotifications && vm.notificationsGranted {
            out.append("Reminders on")
        }
        if out.isEmpty { out.append("Quiet & visible") }
        return out
    }

    private var locationLine: String {
        let countryName = vm.country.flatMap {
            Locale.current.localizedString(forRegionCode: $0)
        }
        return [vm.city.isEmpty ? nil : vm.city, countryName]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var hasLocation: Bool {
        !vm.city.isEmpty || vm.country != nil
    }

    private var initials: String {
        let parts = vm.displayName.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined()
        return s.isEmpty ? "··" : s.uppercased()
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
