import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: RoomViewModel?

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
                    Toggle("Ghost", isOn: Bindable(vm).isGhost)
                        .toggleStyle(.button)
                        .tint(FTColor.gold)
                        .font(FTType.caption(11))
                }
            }
        }
        .task {
            if vm == nil {
                vm = RoomViewModel(
                    roomID: roomID,
                    realtime: container.realtime,
                    analytics: container.analytics
                )
                // Ghost default will be sourced from profile prefs in M13.
                await vm?.enter(asGhost: false)
            }
        }
    }

    private func content(vm: RoomViewModel) -> some View {
        VStack(spacing: 0) {
            header(vm: vm)
            PresenceRail(presence: vm.presence)
                .padding(.vertical, FTSpace.sm)
            Divider().background(FTColor.divider)
            ChatList(messages: vm.messages, onScrollTop: { Task { await vm.loadOlder() } })
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
        }
        .padding(FTSpace.lg)
        .background(FTColor.surfaceLo)
        .overlay(alignment: .top) { GoldDivider().opacity(0.3) }
    }
}
