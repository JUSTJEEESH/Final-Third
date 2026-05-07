import SwiftUI

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(DeepLinkRouter.self) private var router
    @State private var vm: HomeViewModel?
    @State private var showLightUp = false
    @State private var showUsualEditor = false

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
        .fullScreenCover(isPresented: $showLightUp) {
            if case .signedIn(let userID) = container.auth.state {
                SessionFlowView(userID: userID, roomID: nil,
                                isGhost: vm?.profile?.ghostModeDefault ?? false)
            }
        }
        .sheet(isPresented: $showUsualEditor,
               onDismiss: { Task { await vm?.load() } }) {
            TheUsualEditor()
        }
    }

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Greeting(
                    name: vm.profile?.displayName,
                    streak: vm.usual?.streakCount ?? 0,
                    hasUsual: vm.usual?.cigarID != nil
                )
                lightUpButton
                if let cigar = vm.tonightsPick {
                    TonightsPick(cigar: cigar, source: vm.tonightsPickSource)
                } else {
                    TonightsPickPlaceholder { showUsualEditor = true }
                }
                YourRitual(
                    usual: vm.usual,
                    cigar: vm.usualCigar,
                    drink: vm.usualDrink,
                    onTap: { showUsualEditor = true }
                )
                if let drop = vm.currentDrop, let cigar = vm.dropCigar {
                    DropOfTheWeek(drop: drop, cigar: cigar)
                } else if let upcoming = vm.upcomingDrop, let cigar = vm.upcomingDropCigar {
                    UpcomingDropTeaser(drop: upcoming, cigar: cigar)
                }
                ActiveRooms(rooms: vm.activeRooms)
                if !vm.nearbyEvents.isEmpty {
                    NearbyTonight(events: vm.nearbyEvents, city: vm.profile?.city)
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private var lightUpButton: some View {
        Button {
            HapticsService.shared.tap()
            showLightUp = true
        } label: {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(LinearGradient(
                        colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .font(.system(size: 22))
                    .shadow(color: FTColor.ember.opacity(0.6), radius: 10, x: 0, y: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Light up").font(FTType.heading(18, weight: .semibold))
                    Text("Choose your cigar and step in.")
                        .font(FTType.caption(11))
                        .foregroundStyle(FTColor.inkInverse.opacity(0.7))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(FTColor.inkInverse)
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(GoldSurface())
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(FTColor.goldDeep.opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: FTColor.goldDeep.opacity(0.55), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Light up — start a session")
    }
}

private struct Greeting: View {
    let name: String?
    let streak: Int
    let hasUsual: Bool

    private var firstName: String? {
        guard let name else { return nil }
        return name.split(separator: " ").first.map(String.init)
    }

    var body: some View {
        HStack(alignment: .top) {
            GreetingLine(
                copy: GreetingCopy.make(streak: streak, hasUsual: hasUsual),
                firstName: firstName
            )
            Spacer(minLength: FTSpace.md)
            if streak > 0 { EmberBadge(streakCount: streak) }
        }
        .padding(.top, FTSpace.lg)
    }
}

private struct TonightsPick: View {
    let cigar: Cigar
    let source: HomeViewModel.TonightsPickSource?

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Tonight's Pick")
            NavigationLink(value: AppRoute.cigar(cigar.id)) {
                ZStack(alignment: .topLeading) {
                    // Card surface — tobacco leaf texture as the wrapper
                    // motif, slight gold inner gloss to lift the corners.
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .fill(FTColor.surfaceHi)
                    TexturePanel(texture: .tobaccoLeaf, opacity: 0.32, zoom: 1.8)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg,
                                                    style: .continuous))
                    // Warm ember glow seeping in from the right where
                    // the flame icon sits.
                    RadialGradient(
                        colors: [FTColor.ember.opacity(0.35), .clear],
                        center: UnitPoint(x: 1.0, y: 0.5),
                        startRadius: 10, endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg,
                                                style: .continuous))

                    // Gold leaf top hairline — feels embossed.
                    VStack {
                        LinearGradient(
                            colors: [.clear, FTColor.gold.opacity(0.6), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        Spacer()
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(cigar.brand.uppercased())
                                    .font(FTType.caption(10, weight: .semibold))
                                    .foregroundStyle(FTColor.gold)
                                    .tracking(2)
                                if let badge = sourceBadge {
                                    Text(badge)
                                        .font(FTType.caption(9, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(FTColor.inkInverse)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(FTColor.gold)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(cigar.line)
                                .font(FTType.display(24, weight: .semibold))
                                .foregroundStyle(FTColor.ink)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if let v = cigar.vitola {
                                Text(v)
                                    .font(FTType.caption(12))
                                    .foregroundStyle(FTColor.inkMuted)
                            }
                            HStack(spacing: FTSpace.sm) {
                                if let country = cigar.country {
                                    metaChip(country)
                                }
                                if let wrapper = cigar.wrapper {
                                    metaChip(wrapper)
                                }
                                if let s = cigar.strength,
                                   let label = Cigar.Strength(rawValue: s)?.label {
                                    metaChip(label)
                                }
                            }
                            .padding(.top, 4)
                        }
                        Spacer(minLength: FTSpace.md)
                        Image(systemName: "flame.fill")
                            .foregroundStyle(LinearGradient(
                                colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .font(.system(size: 36))
                            .shadow(color: FTColor.ember.opacity(0.7),
                                    radius: 14, x: 0, y: 0)
                    }
                    .padding(FTSpace.lg)
                }
                .frame(minHeight: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
                .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)
            }.buttonStyle(.plain)
        }
    }

    /// Small gold tag describing why this cigar was chosen — gives the
    /// section editorial weight instead of feeling random.
    private var sourceBadge: String? {
        switch source {
        case .liveDrop: return "LIVE DROP"
        case .upcomingDrop(let daysAway):
            if daysAway <= 0 { return "TODAY" }
            if daysAway == 1 { return "TOMORROW" }
            if daysAway < 7 {
                let weekday = Calendar.current.date(
                    byAdding: .day, value: daysAway, to: .now
                )?.formatted(.dateTime.weekday(.wide)) ?? ""
                return weekday.uppercased()
            }
            return "COMING SOON"
        case .dailyFeatured: return "FEATURED TONIGHT"
        case .none: return nil
        }
    }

    private func metaChip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(FTType.caption(9, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(FTColor.inkMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(FTColor.surfaceLo.opacity(0.6))
            .clipShape(Capsule())
    }
}

/// Placeholder shown on Home when there's no Usual cigar set, no live
/// drop, and no upcoming drop with a featured cigar. Atmosphere-first
/// nudge to set The Usual rather than a cold "no data" gap.
private struct TonightsPickPlaceholder: View {
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Tonight's Pick")
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .fill(FTColor.surface)
                    TexturePanel(texture: .tobaccoLeaf, opacity: 0.15, zoom: 1.6)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg,
                                                    style: .continuous))

                    HStack(alignment: .center, spacing: FTSpace.md) {
                        ZStack {
                            Circle()
                                .stroke(FTColor.gold.opacity(0.55),
                                        lineWidth: FTStroke.thin)
                                .frame(width: 48, height: 48)
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(FTColor.gold)
                                .font(.system(size: 18, weight: .medium))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PICK YOUR USUAL")
                                .font(FTType.caption(10, weight: .semibold))
                                .foregroundStyle(FTColor.gold)
                                .tracking(1.6)
                            Text("Your nightly cigar lives here.")
                                .font(FTType.body(15, weight: .medium))
                                .foregroundStyle(FTColor.ink)
                            Text("Tap to set it — we'll surface it every night.")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkMuted)
                                .padding(.top, 1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(FTColor.inkFaint)
                    }
                    .padding(FTSpace.lg)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
                .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct YourRitual: View {
    let usual: Usual?
    let cigar: Cigar?
    let drink: Drink?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Your Ritual")
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .fill(FTColor.surface)
                    TexturePanel(texture: .leather, opacity: 0.18, zoom: 1.4)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg,
                                                    style: .continuous))

                    HStack(alignment: .top, spacing: FTSpace.lg) {
                        // Time block — display serif, big.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("YOUR USUAL")
                                .font(FTType.caption(9, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(FTColor.gold.opacity(0.8))
                            Text(timeText)
                                .font(FTType.display(28, weight: .semibold))
                                .foregroundStyle(FTColor.ink)
                            HStack(spacing: 4) {
                                Image(systemName: reminderIcon)
                                    .font(.system(size: 10))
                                Text(reminderText)
                                    .font(FTType.caption(10, weight: .medium))
                            }
                            .foregroundStyle(reminderColor)
                            .padding(.top, 4)
                        }
                        .frame(width: 110, alignment: .leading)

                        // Vertical divider — gold thread.
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, FTColor.gold.opacity(0.4), .clear],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 4)

                        // Cigar + drink stack.
                        VStack(alignment: .leading, spacing: 8) {
                            ritualLine(
                                icon: "leaf",
                                label: cigarLabel,
                                placeholder: "Pick a cigar"
                            )
                            ritualLine(
                                icon: "wineglass",
                                label: drinkLabel,
                                placeholder: "Optional pour"
                            )
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(FTColor.inkFaint)
                            .padding(.top, 2)
                    }
                    .padding(FTSpace.lg)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                        .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                )
                .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func ritualLine(icon: String, label: String?, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(label == nil ? FTColor.inkFaint : FTColor.gold)
                .font(.system(size: 12))
                .frame(width: 14)
            Text(label ?? placeholder)
                .font(FTType.body(14, weight: label == nil ? .regular : .medium))
                .foregroundStyle(label == nil ? FTColor.inkFaint : FTColor.ink)
                .lineLimit(1)
        }
    }

    private var timeText: String {
        guard let t = usual?.preferredTime else { return "—:—" }
        var c = DateComponents(); c.hour = t.hour; c.minute = t.minute
        let date = Calendar.current.date(from: c) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var cigarLabel: String? { cigar?.displayName }
    private var drinkLabel: String? { drink?.name }

    private var reminderIcon: String {
        guard let usual else { return "bell.slash" }
        return usual.enabled ? "bell.fill" : "bell.slash"
    }

    private var reminderText: String {
        guard let usual else { return "Set your ritual" }
        return usual.enabled ? "Reminder on" : "Reminder off"
    }

    private var reminderColor: Color {
        guard let usual else { return FTColor.inkMuted }
        return usual.enabled ? FTColor.gold : FTColor.inkMuted
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

private struct UpcomingDropTeaser: View {
    let drop: CigarDrop
    let cigar: Cigar

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Coming Soon")
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .fill(FTColor.surface)
                TexturePanel(texture: .leather, opacity: 0.18, zoom: 1.4)
                    .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg,
                                                style: .continuous))

                HStack(alignment: .center, spacing: FTSpace.md) {
                    // Hourglass icon framed in a thin gold ring.
                    ZStack {
                        Circle()
                            .stroke(FTColor.gold.opacity(0.65),
                                    lineWidth: FTStroke.thin)
                            .frame(width: 48, height: 48)
                        Image(systemName: "hourglass")
                            .foregroundStyle(FTColor.gold)
                            .font(.system(size: 18, weight: .medium))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(whenText.uppercased())
                            .font(FTType.caption(10, weight: .semibold))
                            .foregroundStyle(FTColor.gold)
                            .tracking(1.6)
                        Text(cigar.line)
                            .font(FTType.heading(18, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                        if let copy = drop.heroCopy {
                            Text(copy)
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.inkMuted)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                }
                .padding(FTSpace.lg)
            }
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
            )
            .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 4)
        }
    }

    private var whenText: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: .now, to: drop.startsAt).day ?? 0
        if days <= 0 { return "Lighting up today" }
        if days == 1 { return "Tomorrow" }
        if days < 7 {
            return drop.startsAt.formatted(.dateTime.weekday(.wide))
        }
        return drop.startsAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct ActiveRooms: View {
    let rooms: [Room]

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Active Rooms")
            if rooms.isEmpty {
                FTCard {
                    HStack(spacing: FTSpace.md) {
                        Image(systemName: "smoke")
                            .foregroundStyle(FTColor.inkFaint)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet so far tonight.")
                                .font(FTType.body(14, weight: .medium))
                            Text("Step in. Someone always shows up.")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkMuted)
                        }
                        Spacer()
                    }
                }
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
