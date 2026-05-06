import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile?
    @State private var notifAuth: String = "—"
    @State private var showPaywall = false
    @State private var showUsual = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                Form { content }
                    .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(FTColor.gold)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(trigger: "settings") }
            .sheet(isPresented: $showUsual) { TheUsualEditor() }
        }
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        Section("Account") {
            row("Name", value: profile?.displayName ?? "—")
            if let handle = profile?.handle { row("Handle", value: "@\(handle)") }
            if let email = profile?.email { row("Email", value: email) }
            Button(role: .destructive) {
                Task { await container.auth.signOut() }
            } label: { Text("Sign out") }
        }

        Section("Ritual") {
            Button {
                HapticsService.shared.tap()
                showUsual = true
            } label: {
                HStack {
                    Text("The Usual").foregroundStyle(FTColor.ink)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                }
            }
        }

        Section("Audio") {
            audioPicker
        }

        Section("Voice") {
            Toggle("Allow voice rooms", isOn: Binding(
                get: { profile?.voiceEnabled ?? false },
                set: { on in Task { await update(voiceEnabled: on) } }
            )).tint(FTColor.gold)
            Text("You'll always be muted by default. Hold to talk.")
                .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
        }

        Section("Privacy") {
            Toggle("Ghost by default", isOn: Binding(
                get: { profile?.ghostModeDefault ?? false },
                set: { on in Task { await update(ghostDefault: on) } }
            )).tint(FTColor.gold)
            Text("Step in invisibly. No notifications fire on arrival.")
                .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
        }

        Section("Notifications") {
            row("Permission", value: notifAuth)
            Button("Request notifications") {
                Task { await container.notifications.requestAuthorization(); await refreshNotifAuth() }
            }
        }

        Section("Membership") {
            row("Status", value: container.entitlements.isPremium ? "Member" : "Free")
            if container.entitlements.isPremium {
                if let renews = container.entitlements.renewsAt {
                    row("Renews", value: renews.formatted(date: .abbreviated, time: .omitted))
                }
            } else {
                Button("Become a member") { showPaywall = true }
                    .tint(FTColor.gold)
            }
            Button("Restore purchases") {
                Task { try? await container.entitlements.restore() }
            }
        }

        Section("About") {
            row("Version", value: appVersion())
            if let url = URL(string: "https://thefinalthird.app/privacy") {
                Link("Privacy", destination: url)
            }
            if let url = URL(string: "https://thefinalthird.app/terms") {
                Link("Terms", destination: url)
            }
        }

        if let error {
            Text(error).font(FTType.caption(12)).foregroundStyle(FTColor.danger)
        }
    }

    private var audioPicker: some View {
        Picker(selection: Binding(
            get: { profile?.audioTheme ?? .loungeMurmur },
            set: { theme in Task { await update(audioTheme: theme) } }
        ), label: Text("Default ambience")) {
            ForEach(AudioTheme.allCases, id: \.self) { theme in
                Text(theme.displayName).tag(theme)
            }
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(FTColor.inkMuted)
            Spacer()
            Text(value).foregroundStyle(FTColor.ink)
        }
    }

    // MARK: Actions

    private func load() async {
        guard case .signedIn(let userID) = container.auth.state else { return }
        let repo: ProfileRepository = LiveProfileRepository()
        profile = try? await repo.fetch(id: userID)
        await refreshNotifAuth()
    }

    private func refreshNotifAuth() async {
        await container.notifications.bootstrap()
        switch container.notifications.authorization {
        case .authorized: notifAuth = "On"
        case .provisional: notifAuth = "Provisional"
        case .denied: notifAuth = "Off"
        case .notDetermined: notifAuth = "Not asked"
        case .ephemeral: notifAuth = "Ephemeral"
        @unknown default: notifAuth = "—"
        }
    }

    private func update(audioTheme: AudioTheme) async {
        do {
            try await LiveProfileRepository().updatePreferences(
                audioTheme: audioTheme, voiceEnabled: nil, ghostModeDefault: nil
            )
            profile?.audioTheme = audioTheme
        } catch { self.error = error.localizedDescription }
    }

    private func update(voiceEnabled: Bool) async {
        do {
            try await LiveProfileRepository().updatePreferences(
                audioTheme: nil, voiceEnabled: voiceEnabled, ghostModeDefault: nil
            )
            profile?.voiceEnabled = voiceEnabled
        } catch { self.error = error.localizedDescription }
    }

    private func update(ghostDefault: Bool) async {
        do {
            try await LiveProfileRepository().updatePreferences(
                audioTheme: nil, voiceEnabled: nil, ghostModeDefault: ghostDefault
            )
            profile?.ghostModeDefault = ghostDefault
        } catch { self.error = error.localizedDescription }
    }

    private func appVersion() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }
}
