import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: RoomViewModel?
    @State private var showAmbientPicker = false

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            if let vm { content(vm: vm) }
            else { ProgressView().tint(FTColor.gold) }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task {
                        await vm?.leave()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Leave").font(FTType.caption(13))
                    }.foregroundStyle(FTColor.inkMuted)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let vm {
                    HStack(spacing: FTSpace.sm) {
                        Button {
                            HapticsService.shared.tap()
                            showAmbientPicker = true
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(vm.ambientTheme == nil ? FTColor.inkMuted : FTColor.gold)
                        }
                        Toggle("Ghost", isOn: Bindable(vm).isGhost)
                            .toggleStyle(.button)
                            .tint(FTColor.gold)
                            .font(FTType.caption(11))
                    }
                }
            }
        }
        .task {
            if vm == nil {
                vm = RoomViewModel(
                    roomID: roomID,
                    realtime: container.realtime,
                    voice: container.voice,
                    audio: container.audio,
                    analytics: container.analytics
                )
                let asGhost = await defaultGhost()
                await vm?.enter(asGhost: asGhost)
            }
        }
        .sheet(isPresented: $showAmbientPicker) {
            if let vm { AmbientPickerSheet(vm: vm) }
        }
    }

    /// Pulls ghost-by-default off the user's profile; safe to call repeatedly.
    private func defaultGhost() async -> Bool {
        guard case .signedIn(let userID) = container.auth.state else { return false }
        let repo: ProfileRepository = LiveProfileRepository()
        let profile = try? await repo.fetch(id: userID)
        return profile?.ghostModeDefault ?? false
    }

    private func content(vm: RoomViewModel) -> some View {
        VStack(spacing: 0) {
            header(vm: vm)
            LightUpHereCTA(vm: vm)
            PresenceRail(presence: vm.presence, smokers: vm.smokersByUser)
                .padding(.vertical, FTSpace.sm)
            Divider().background(FTColor.divider)
            ChatList(messages: vm.messages, onScrollTop: { Task { await vm.loadOlder() } })
            VoiceBar(vm: vm)
            ComposerBar(text: Bindable(vm).draft) { Task { await vm.send() } }
        }
    }

    private func header(vm: RoomViewModel) -> some View {
        VStack(spacing: 4) {
            Text(vm.room?.name ?? "Lounge").font(FTType.heading(18, weight: .semibold))
            HStack(spacing: 6) {
                if !vm.smokersByUser.isEmpty {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(FTColor.gold)
                        .font(.system(size: 10))
                    Text("\(vm.smokersByUser.count) lit up")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
                        .tracking(0.8)
                    if vm.room?.theme != nil { Text("·").foregroundStyle(FTColor.inkFaint) }
                }
                if let theme = vm.room?.theme {
                    Text(theme).font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                }
            }
        }
        .padding(.horizontal, FTSpace.lg).padding(.top, FTSpace.md)
    }
}

// MARK: - Light Up Here CTA

/// Path B entry — the user is in the room, taps "Light up here", and
/// the ceremony plays full-screen. When they emerge, they're lit and
/// already seated. The CTA changes to a focus tile when they have an
/// active session in this room, or "You're lit elsewhere" when in
/// another room.
private struct LightUpHereCTA: View {
    @Environment(AppContainer.self) private var container
    @Bindable var vm: RoomViewModel

    var body: some View {
        Group {
            switch state {
            case .available:
                lightUpButton
            case .activeHere:
                inSessionTile
            case .activeElsewhere(let otherRoomName):
                elsewhereTile(otherRoomName: otherRoomName)
            }
        }
        .padding(.horizontal, FTSpace.lg)
        .padding(.top, FTSpace.sm)
    }

    private enum State {
        case available
        case activeHere
        case activeElsewhere(roomName: String)
    }

    private var state: State {
        guard container.session.isInFlow else { return .available }
        if container.session.activeRoomID == vm.roomID {
            return .activeHere
        }
        // Session is in some other room (or solo). For Step 4 we show
        // a generic "elsewhere" tile — Step 6 will add "Move over here".
        if let otherID = container.session.activeRoomID, otherID != vm.roomID {
            return .activeElsewhere(roomName: container.session.current?.chosenRoom?.name ?? "another room")
        }
        return .activeElsewhere(roomName: "solo")
    }

    private var lightUpButton: some View {
        Button {
            HapticsService.shared.tap()
            guard case .signedIn(let userID) = container.auth.state else { return }
            container.session.beginFlow(
                userID: userID,
                room: vm.room,
                isGhost: vm.isGhost,
                analytics: container.analytics
            )
            container.session.expand()
        } label: {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(LinearGradient(
                        colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .font(.system(size: 16))
                    .shadow(color: FTColor.ember.opacity(0.5), radius: 6)
                Text("Light up here")
                    .font(FTType.body(14, weight: .semibold))
                    .foregroundStyle(FTColor.inkInverse)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FTColor.inkInverse)
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.sm + 2)
            .background(GoldSurface())
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(FTColor.goldDeep.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: FTColor.goldDeep.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var inSessionTile: some View {
        Button {
            HapticsService.shared.tap()
            container.session.expand()
        } label: {
            HStack(spacing: FTSpace.md) {
                EmberDot()
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU'RE LIT")
                        .font(FTType.caption(10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(FTColor.gold)
                    if let cigar = container.session.activeCigar {
                        Text("\(cigar.brand) \(cigar.line)")
                            .font(FTType.body(13, weight: .medium))
                            .foregroundStyle(FTColor.ink)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("Open")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.gold)
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.vertical, FTSpace.sm)
            .background(FTColor.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(FTColor.gold.opacity(0.45), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    private func elsewhereTile(otherRoomName: String) -> some View {
        HStack(spacing: FTSpace.sm) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(FTColor.inkFaint)
                .font(.system(size: 12))
            Text(otherRoomName == "solo"
                 ? "You're lit solo right now."
                 : "You're lit at \(otherRoomName).")
                .font(FTType.caption(12))
                .foregroundStyle(FTColor.inkMuted)
            Spacer()
            Button("Open") {
                HapticsService.shared.tap()
                container.session.expand()
            }
            .font(FTType.caption(12, weight: .semibold))
            .foregroundStyle(FTColor.gold)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FTSpace.lg)
        .padding(.vertical, FTSpace.sm)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
    }
}

private struct EmberDot: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 9, height: 9)
            .shadow(color: FTColor.ember.opacity(pulse ? 0.85 : 0.5), radius: pulse ? 5 : 3)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }
}

private struct PresenceRail: View {
    let presence: [RoomPresence]
    /// Live smokers (from `room_live_now`) keyed by userID. Avatars
    /// of smokers get a gold halo + the smoker's cigar shows on tap
    /// inline. Non-smokers render as today.
    let smokers: [UUID: LiveNowSummary.Smoker]

    /// Smokers float to the front of the rail so the eye lands on
    /// active humans first — same magnetic principle as the doorway
    /// sheet's "Lit up right now" section.
    private var sortedPresence: [RoomPresence] {
        presence.sorted { lhs, rhs in
            let lhsLit = smokers[lhs.userID] != nil
            let rhsLit = smokers[rhs.userID] != nil
            if lhsLit != rhsLit { return lhsLit }
            return lhs.joinedAt < rhs.joinedAt
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpace.sm) {
                ForEach(sortedPresence, id: \.userID) { p in
                    PresenceChip(presence: p, smoker: smokers[p.userID])
                }
            }
            .padding(.horizontal, FTSpace.lg)
        }
    }
}

private struct PresenceChip: View {
    let presence: RoomPresence
    let smoker: LiveNowSummary.Smoker?

    var body: some View {
        if let smoker {
            HStack(spacing: 8) {
                ZStack {
                    AvatarView(
                        url: presence.avatarURL,
                        initials: String(presence.displayName.prefix(2)).uppercased(),
                        size: 30, isGhost: false, isActive: true
                    )
                    Circle()
                        .stroke(FTColor.gold.opacity(0.8), lineWidth: 1.2)
                        .frame(width: 32, height: 32)
                        .shadow(color: FTColor.ember.opacity(0.5), radius: 4)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(presence.displayName)
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.ink)
                        .lineLimit(1)
                    if let cigar = smoker.cigarDisplay {
                        Text("\(cigar) · \(smoker.minutesIn) min")
                            .font(FTType.caption(10))
                            .foregroundStyle(FTColor.gold.opacity(0.85))
                            .lineLimit(1)
                    } else {
                        Text("\(smoker.minutesIn) min in")
                            .font(FTType.caption(10))
                            .foregroundStyle(FTColor.gold.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FTColor.surfaceHi)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(FTColor.gold.opacity(0.35), lineWidth: 0.5)
            )
        } else {
            AvatarView(
                url: presence.avatarURL,
                initials: String(presence.displayName.prefix(2)).uppercased(),
                size: 32, isGhost: presence.isGhost, isActive: !presence.isGhost
            )
        }
    }
}

private struct ChatList: View {
    let messages: [Message]
    let onScrollTop: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FTSpace.xs) {
                    Color.clear.frame(height: 1)
                        .onAppear(perform: onScrollTop)
                    ForEach(messages) { msg in
                        MessageRow(message: msg).id(msg.id)
                    }
                }
                .padding(.horizontal, FTSpace.lg)
                .padding(.vertical, FTSpace.md)
            }
            .onChange(of: messages.last?.id) { _, last in
                guard let last else { return }
                withAnimation(FTMotion.easeOutSoft) { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }
}

private struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: FTSpace.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(message.body).font(FTType.body(15))
                    .foregroundStyle(FTColor.ink)
                    .opacity(opacity)
                if case .failed(let reason) = message.pendingState {
                    Text("Couldn't send: \(reason)")
                        .font(FTType.caption(10)).foregroundStyle(FTColor.danger)
                }
            }
            Spacer()
            Text(message.createdAt, style: .time)
                .font(FTType.caption(10)).foregroundStyle(FTColor.inkFaint)
        }
        .padding(FTSpace.sm)
    }

    private var opacity: Double {
        switch message.pendingState {
        case .synced: return 1
        case .pending: return 0.55
        case .failed: return 0.5
        }
    }
}

private struct VoiceBar: View {
    @Bindable var vm: RoomViewModel

    var body: some View {
        HStack(spacing: FTSpace.md) {
            if vm.voiceJoined {
                PushToTalkButton(
                    isTransmitting: false /* read from VoiceService inside VM in v2 */,
                    isJoined: true,
                    onPressChange: { on in Task { await vm.setTransmitting(on) } }
                )
                Text("Hold to talk")
                    .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
            } else {
                Button {
                    Task { await vm.joinVoice() }
                } label: {
                    HStack(spacing: FTSpace.sm) {
                        Image(systemName: "mic.slash")
                        Text(vm.isGhost ? "Voice off in ghost mode" : "Tap to join voice")
                            .font(FTType.caption(12, weight: .medium))
                    }
                    .padding(.horizontal, FTSpace.md).padding(.vertical, FTSpace.sm)
                    .background(FTColor.surface)
                    .foregroundStyle(vm.isGhost ? FTColor.inkFaint : FTColor.inkMuted)
                    .clipShape(Capsule())
                }
                .disabled(vm.isGhost)
            }
            Spacer()
        }
        .padding(.horizontal, FTSpace.lg)
        .padding(.vertical, FTSpace.sm)
        .background(FTColor.surfaceLo.opacity(0.5))
    }
}

private struct ComposerBar: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: FTSpace.sm) {
            TextField("", text: $text, prompt: Text("Say something quiet…")
                .foregroundColor(FTColor.inkFaint))
                .textFieldStyle(.plain)
                .padding(FTSpace.md)
                .background(FTColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                .foregroundStyle(FTColor.ink)
                .accessibilityLabel("Message")
            Button(action: {
                HapticsService.shared.tap()
                onSend()
            }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FTColor.inkInverse)
                    .padding(12)
                    .background(text.isEmpty ? FTColor.divider : FTColor.gold)
                    .clipShape(Circle())
            }
            .disabled(text.isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(FTSpace.lg)
        .background(FTColor.surfaceLo)
        .overlay(alignment: .top) { GoldDivider().opacity(0.3) }
    }
}

private struct AmbientPickerSheet: View {
    @Bindable var vm: RoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        vm.setAmbient(nil)
                        HapticsService.shared.tap()
                    } label: {
                        HStack {
                            Text("Silence").foregroundStyle(FTColor.ink)
                            Spacer()
                            if vm.ambientTheme == nil {
                                Image(systemName: "checkmark").foregroundStyle(FTColor.gold)
                            }
                        }
                    }
                }
                Section("Ambience") {
                    ForEach(AudioTheme.allCases, id: \.self) { theme in
                        Button {
                            vm.setAmbient(theme)
                            HapticsService.shared.tap()
                        } label: {
                            HStack {
                                Text(theme.displayName).foregroundStyle(FTColor.ink)
                                Spacer()
                                if vm.ambientTheme == theme {
                                    Image(systemName: "checkmark").foregroundStyle(FTColor.gold)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FTColor.background)
            .navigationTitle("Ambience")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
