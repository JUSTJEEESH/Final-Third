import SwiftUI

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: ProfileViewModel?
    @State private var showSettings = false
    @State private var showUsual = false

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                if let vm { content(vm) } else { ProgressView().tint(FTColor.gold) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsService.shared.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape").foregroundStyle(FTColor.gold)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showUsual) { TheUsualEditor() }
        .task {
            if vm == nil, case .signedIn(let userID) = container.auth.state {
                vm = ProfileViewModel(userID: userID)
                await vm?.load()
            }
        }
    }

    var openUsual: () -> Void { { showUsual = true } }

    @ViewBuilder
    private func content(_ vm: ProfileViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                header(vm: vm)
                statsRow(vm: vm)
                ritualCard(vm: vm)
                ChemistrySection(rows: vm.chemistry)
                ConnectionsSection(connections: vm.connections, currentUserID: vm.profile?.id)
                preferences(vm: vm)
                signOutButton
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private func ritualCard(vm: ProfileViewModel) -> some View {
        Button {
            HapticsService.shared.tap()
            showUsual = true
        } label: {
            FTCard(elevated: true) {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(FTColor.gold)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The Usual")
                            .font(FTType.body(15, weight: .semibold))
                        Text(vm.usual?.enabled == true ? "Reminder set." : "Set your nightly ritual.")
                            .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                }
            }
        }.buttonStyle(.plain)
    }

    private func header(vm: ProfileViewModel) -> some View {
        HStack(spacing: FTSpace.md) {
            AvatarView(
                url: vm.profile?.avatarURL,
                initials: vm.profile?.initials ?? "··",
                size: 56,
                isActive: true
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.profile?.displayName ?? "—").font(FTType.heading(20))
                if let handle = vm.profile?.handle {
                    Text("@\(handle)").font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                }
                if let city = vm.profile?.city {
                    Text(city).font(FTType.caption(12)).foregroundStyle(FTColor.inkFaint)
                }
            }
            Spacer()
        }
        .padding(.top, FTSpace.lg)
    }

    private func statsRow(vm: ProfileViewModel) -> some View {
        HStack(spacing: FTSpace.md) {
            stat("Streak", value: "\(vm.usual?.streakCount ?? 0)")
            stat("Connections", value: "\(vm.connections.filter { $0.status == .accepted }.count)")
            stat("Badges", value: "\(vm.badgeCount)")
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(FTType.caption(10, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            Text(value).font(FTType.display(22))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpace.md)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
    }

    private func preferences(vm: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.md) {
            Text("Preferences").font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            FTCard {
                VStack(spacing: FTSpace.md) {
                    HStack {
                        Text("Default audio").font(FTType.body(15))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.profile?.audioTheme ?? .loungeMurmur },
                            set: { theme in Task { await vm.updateAudioPref(theme) } }
                        )) {
                            ForEach(AudioTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(FTColor.gold)
                    }
                    Toggle(isOn: Binding(
                        get: { vm.profile?.ghostModeDefault ?? false },
                        set: { on in Task { await vm.updateGhostDefault(on) } }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ghost by default").font(FTType.body(15))
                            Text("Step in invisibly. No notifications fire.")
                                .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                        }
                    }
                    .tint(FTColor.gold)
                }
            }
        }
    }

    private var signOutButton: some View {
        FTButton(title: "Sign out", style: .ghost) {
            Task { await container.auth.signOut() }
        }
        .padding(.top, FTSpace.lg)
    }
}

private struct ChemistrySection: View {
    let rows: [ConnectionChemistry]

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("Chemistry").font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            if rows.isEmpty {
                Text("Smoke with someone and we'll start tracking.")
                    .font(FTType.caption(13)).foregroundStyle(FTColor.inkFaint)
            } else {
                ForEach(rows.prefix(3), id: \.userA) { row in
                    FTCard {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You smoke well together")
                                .font(FTType.body(14)).foregroundStyle(FTColor.gold)
                            Text("\(row.sessionsTogether) sessions • \(row.minutesTogether)m")
                                .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                        }
                    }
                }
            }
        }
    }
}

private struct ConnectionsSection: View {
    let connections: [Connection]
    let currentUserID: UUID?

    var pending: [Connection] {
        connections.filter { $0.status == .pending && $0.addresseeID == currentUserID }
    }

    var accepted: [Connection] {
        connections.filter { $0.status == .accepted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("Connections").font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            if !pending.isEmpty {
                Text("Pending requests").font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                ForEach(pending) { _ in
                    FTCard {
                        HStack {
                            Text("Someone wants to connect.").font(FTType.body(14))
                            Spacer()
                        }
                    }
                }
            }
            if accepted.isEmpty {
                Text("No connections yet.").font(FTType.caption(13)).foregroundStyle(FTColor.inkFaint)
            } else {
                ForEach(accepted) { _ in
                    FTCard {
                        HStack {
                            AvatarView(url: nil, initials: "··", size: 32)
                            Text("Connected").font(FTType.body(14))
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
