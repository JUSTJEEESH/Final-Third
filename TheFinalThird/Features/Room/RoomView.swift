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
            PresenceRail(presence: vm.presence)
                .padding(.vertical, FTSpace.sm)
            Divider().background(FTColor.divider)
            ChatList(messages: vm.messages, onScrollTop: { Task { await vm.loadOlder() } })
            VoiceBar(vm: vm)
            ComposerBar(text: Bindable(vm).draft) { Task { await vm.send() } }
        }
    }

    private func header(vm: RoomViewModel) -> some View {
        VStack(spacing: 2) {
            Text(vm.room?.name ?? "Lounge").font(FTType.heading(18, weight: .semibold))
            if let theme = vm.room?.theme {
                Text(theme).font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
            }
        }
        .padding(.horizontal, FTSpace.lg).padding(.top, FTSpace.md)
    }
}

private struct PresenceRail: View {
    let presence: [RoomPresence]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpace.xs) {
                ForEach(presence, id: \.userID) { p in
                    AvatarView(url: p.avatarURL,
                               initials: String(p.displayName.prefix(2)).uppercased(),
                               size: 32, isGhost: p.isGhost, isActive: !p.isGhost)
                }
            }
            .padding(.horizontal, FTSpace.lg)
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
