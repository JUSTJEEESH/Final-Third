import SwiftUI

/// "Where are you sitting?" — the doorway sheet shown after the
/// Lighting Ceremony completes. The single biggest moment for pulling
/// solo users into the social half of the app: the cigar's lit, the
/// flame is still glowing in their eyes, and we offer them company
/// or quiet, never forcing.
///
/// Sections (top → bottom — magnetism first):
///   • Lit up right now — rooms with active smokers, names + cigars
///   • By the window — quiet public rooms
///   • Voice rooms — Patron-only (lock + soft upsell)
///   • Stay solo — always last, never default
struct RoomPickerSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    /// When presented mid-session for a room switch, this is the
    /// session's current `roomID` — we hide it from the list (and
    /// refuse to pick it) so the picker never offers "move to where
    /// you already are." Nil for the post-ceremony flow.
    var excludeRoomID: UUID? = nil

    /// Called with `nil` if the user chose "Stay solo" or with the
    /// chosen room. Caller is responsible for kicking off the actual
    /// `startSession(roomID:)` — the picker is presentation-only.
    let onPick: (Room?) -> Void

    @State private var vm = RoomPickerViewModel()
    @State private var pollTask: Task<Void, Never>?
    @State private var showPatronUpsell = false

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            TexturePanel(texture: .leather, opacity: 0.10, zoom: 1.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // Faint warm glow at the top, like the ceremony's afterimage.
            RadialGradient(
                colors: [FTColor.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FTSpace.xl) {
                    header

                    if vm.isLoading && vm.rooms.isEmpty {
                        loadingState
                    } else {
                        if !vm.liveRooms.isEmpty {
                            section(
                                eyebrow: "Lit up right now",
                                copy: nil
                            ) {
                                ForEach(vm.liveRooms) { room in
                                    LiveRoomCard(
                                        room: room,
                                        summary: vm.liveByRoom[room.id],
                                        onTap: { pick(room) }
                                    )
                                }
                            }
                        }

                        if !vm.topicRooms.isEmpty {
                            section(
                                eyebrow: "By the window",
                                copy: "Quiet corners. Pick one — others may join."
                            ) {
                                ForEach(vm.topicRooms) { room in
                                    TopicRoomCard(room: room) { pick(room) }
                                }
                            }
                        }

                        if !vm.voiceRooms.isEmpty {
                            section(
                                eyebrow: "Voice rooms",
                                copy: "Hold to talk. Never always-on. Patrons only."
                            ) {
                                ForEach(vm.voiceRooms) { room in
                                    VoiceRoomCard(
                                        room: room,
                                        isPatron: container.entitlements.isPremium,
                                        onTap: {
                                            if container.entitlements.isPremium {
                                                pick(room)
                                            } else {
                                                HapticsService.shared.tap()
                                                showPatronUpsell = true
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        staySoloRow
                    }
                }
                .padding(.horizontal, FTSpace.xl)
                .padding(.top, FTSpace.lg)
                .padding(.bottom, FTSpace.xxxl)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            vm.excludeRoomID = excludeRoomID
            await vm.load()
            startLiveNowPolling()
        }
        .onDisappear { stopLiveNowPolling() }
        .sheet(isPresented: $showPatronUpsell) {
            PatronSheet(trigger: "voice_room_card")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("THE ROOM IS YOURS")
                .font(FTType.caption(11, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(FTColor.gold)
            Text("Where would you like to sit tonight?")
                .font(FTType.display(28, weight: .semibold))
                .foregroundStyle(FTColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Pick a room or stay solo. Either way, your cigar is already lit.")
                .font(FTType.body(14))
                .foregroundStyle(FTColor.inkMuted)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func section<Content: View>(
        eyebrow: String,
        copy: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(eyebrow.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(FTColor.gold.opacity(0.85))
            if let copy {
                Text(copy)
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.inkMuted)
            }
            VStack(spacing: FTSpace.sm) { content() }
                .padding(.top, 2)
        }
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().tint(FTColor.gold)
            Spacer()
        }
        .padding(.vertical, FTSpace.xxl)
    }

    private var staySoloRow: some View {
        Button {
            HapticsService.shared.tap()
            pick(nil)
        } label: {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(FTColor.inkFaint)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stay solo")
                        .font(FTType.body(15, weight: .medium))
                        .foregroundStyle(FTColor.ink)
                    Text("No room tonight. Just the burn.")
                        .font(FTType.caption(11))
                        .foregroundStyle(FTColor.inkMuted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(FTColor.inkFaint)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .background(FTColor.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, FTSpace.lg)
    }

    // MARK: - Behavior

    private func pick(_ room: Room?) {
        HapticsService.shared.success()
        onPick(room)
        // Caller advances the session phase to .active; we just close.
        dismiss()
    }

    private func startLiveNowPolling() {
        stopLiveNowPolling()
        // Task-based instead of Timer so we don't cross actor
        // boundaries on the timer callback under Swift 6 strict
        // concurrency. The task lives only as long as the sheet is
        // on screen — `onDisappear` cancels it.
        pollTask = Task { @MainActor [vm] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await vm.refreshLiveNow()
            }
        }
    }

    private func stopLiveNowPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}

// MARK: - Live room card

/// The strongest magnet in the picker. Real names, real cigars, real
/// minutes-in. Gold halo on each smoker's avatar mimics the ember
/// glow of the home Light Up button.
private struct LiveRoomCard: View {
    let room: Room
    let summary: LiveNowSummary?
    let onTap: () -> Void

    var body: some View {
        Button(action: { HapticsService.shared.tap(); onTap() }) {
            VStack(alignment: .leading, spacing: FTSpace.md) {
                HStack(spacing: FTSpace.sm) {
                    EmberPip()
                    Text(room.name)
                        .font(FTType.heading(18, weight: .semibold))
                        .foregroundStyle(FTColor.ink)
                    Spacer()
                    Text("\(summary?.liveCount ?? 0) lit up")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
                        .tracking(1)
                }

                if let smokers = summary?.smokers, !smokers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(smokers, id: \.userID) { smoker in
                            SmokerRow(smoker: smoker)
                        }
                        if let total = summary?.liveCount,
                           total > smokers.count
                        {
                            Text("+\(total - smokers.count) more lit up")
                                .font(FTType.caption(11))
                                .foregroundStyle(FTColor.inkFaint)
                                .padding(.top, 2)
                        }
                    }
                }

                HStack(spacing: 4) {
                    if let theme = room.audioTheme {
                        Text(theme.displayName)
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                        Text("·").foregroundStyle(FTColor.inkFaint)
                    }
                    Text("tap to enter")
                        .font(FTType.caption(11))
                        .foregroundStyle(FTColor.inkFaint)
                    Spacer()
                }
            }
            .padding(FTSpace.lg)
            .background(LiveCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(FTColor.gold.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: FTColor.goldGlow.opacity(0.3), radius: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct SmokerRow: View {
    let smoker: LiveNowSummary.Smoker

    var body: some View {
        HStack(spacing: FTSpace.sm) {
            ZStack {
                avatar
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(FTColor.gold.opacity(0.55), lineWidth: 0.7)
                    )
                    .shadow(color: FTColor.ember.opacity(0.35), radius: 4)
                // Patron mark — slightly outset gold ring. Quiet
                // signal, only visible if you know to look.
                if smoker.isPatron {
                    Circle()
                        .stroke(FTColor.gold.opacity(0.9), lineWidth: 1)
                        .frame(width: 26, height: 26)
                        .shadow(color: FTColor.goldGlow.opacity(0.5), radius: 3)
                }
            }

            Text(smoker.displayName)
                .font(FTType.body(13, weight: .medium))
                .foregroundStyle(FTColor.ink)
                .lineLimit(1)

            if let cigar = smoker.cigarDisplay {
                Text(cigar)
                    .font(FTType.caption(11))
                    .foregroundStyle(FTColor.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("\(smoker.minutesIn) min")
                .font(FTType.caption(10, weight: .semibold))
                .foregroundStyle(FTColor.gold.opacity(0.75))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = smoker.avatarURL {
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

    private var placeholder: some View {
        ZStack {
            Circle().fill(FTColor.surfaceHi)
            Text(initial)
                .font(FTType.caption(10, weight: .semibold))
                .foregroundStyle(FTColor.gold.opacity(0.8))
        }
    }

    private var initial: String {
        smoker.displayName.first.map { String($0).uppercased() } ?? "·"
    }
}

private struct EmberPip: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 8, height: 8)
            .shadow(color: FTColor.ember.opacity(pulse ? 0.85 : 0.5), radius: pulse ? 5 : 3)
            .animation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }
}

/// Subtle warm gradient + leather grain underneath the live cards
/// so they read as "hotter" than the topic cards without being loud.
private struct LiveCardBackground: View {
    var body: some View {
        ZStack {
            FTColor.surfaceHi
            TexturePanel(texture: .leather, opacity: 0.12, zoom: 1.5)
                .allowsHitTesting(false)
            LinearGradient(
                colors: [
                    FTColor.gold.opacity(0.10),
                    FTColor.ember.opacity(0.04),
                    .clear,
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Topic room card

private struct TopicRoomCard: View {
    let room: Room
    let onTap: () -> Void

    var body: some View {
        Button(action: { HapticsService.shared.tap(); onTap() }) {
            HStack(spacing: FTSpace.md) {
                Image(systemName: room.isPrivate ? "lock.fill" : "rectangle.fill.on.rectangle.fill")
                    .foregroundStyle(FTColor.gold.opacity(0.65))
                    .font(.system(size: 13))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(FTType.body(15, weight: .medium))
                        .foregroundStyle(FTColor.ink)
                    if let theme = room.audioTheme {
                        Text(theme.displayName)
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    } else if let desc = room.theme {
                        Text(desc)
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(FTColor.inkFaint)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .background(FTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(FTColor.divider, lineWidth: FTStroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice room card

/// Always-visible — free users see what they'd unlock. Tap fires the
/// Patron upsell sheet rather than entering the room.
private struct VoiceRoomCard: View {
    let room: Room
    let isPatron: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(FTColor.gold)
                    .font(.system(size: 13))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(FTType.body(15, weight: .medium))
                        .foregroundStyle(FTColor.ink)
                    Text(isPatron ? "Hold to talk · voice room" : "Patrons only")
                        .font(FTType.caption(11))
                        .foregroundStyle(isPatron ? FTColor.inkMuted : FTColor.gold.opacity(0.75))
                }

                Spacer()
                Image(systemName: isPatron ? "chevron.right" : "lock.fill")
                    .foregroundStyle(isPatron ? FTColor.inkFaint : FTColor.gold)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.md)
            .background(FTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(
                        isPatron ? FTColor.divider : FTColor.gold.opacity(0.35),
                        lineWidth: FTStroke.hairline
                    )
            )
            .opacity(isPatron ? 1 : 0.95)
        }
        .buttonStyle(.plain)
    }
}
