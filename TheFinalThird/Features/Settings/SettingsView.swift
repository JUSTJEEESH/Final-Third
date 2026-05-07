import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var profile: Profile?
    @State private var notifAuth: String = "—"
    @State private var showPaywall = false
    @State private var showUsual = false
    @State private var error: String?
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                TexturePanel(texture: .leather, opacity: 0.08, zoom: 1.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                ScrollView {
                    VStack(alignment: .leading, spacing: FTSpace.xl) {
                        header

                        section(title: "ACCOUNT") {
                            row(label: "Name", value: profile?.displayName ?? "—")
                            if let handle = profile?.handle {
                                divider
                                row(label: "Handle", value: "@\(handle)")
                            }
                            if let email = profile?.email {
                                divider
                                row(label: "Email", value: email)
                            }
                        }

                        section(title: "RITUAL") {
                            navRow(icon: "moon.stars.fill", label: "The Usual",
                                   subtitle: "Time, cigar, drink, reminders") {
                                HapticsService.shared.tap()
                                showUsual = true
                            }
                        }

                        section(title: "AMBIENCE") {
                            HStack {
                                Text("Default ambient")
                                    .font(FTType.body(15))
                                    .foregroundStyle(FTColor.ink)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { profile?.audioTheme ?? .loungeMurmur },
                                    set: { theme in
                                        // Patron gate: free users
                                        // selecting a locked theme
                                        // get the upsell instead of
                                        // the audio change.
                                        if theme.isPatron, !container.entitlements.isPremium {
                                            showPaywall = true
                                        } else {
                                            Task { await update(audioTheme: theme) }
                                        }
                                    }
                                )) {
                                    ForEach(AudioTheme.allCases, id: \.self) { theme in
                                        let locked = theme.isPatron && !container.entitlements.isPremium
                                        Text(locked ? "\(theme.displayName)  🔒" : theme.displayName)
                                            .tag(theme)
                                    }
                                }
                                .labelsHidden()
                                .tint(FTColor.gold)
                            }
                            .padding(.vertical, FTSpace.sm)
                        }

                        section(title: "VOICE") {
                            toggleRow(
                                title: "Allow voice rooms",
                                subtitle: "You're always muted by default. Hold to talk.",
                                value: profile?.voiceEnabled ?? false
                            ) { newValue in
                                Task { await update(voiceEnabled: newValue) }
                            }
                        }

                        section(title: "PRIVACY") {
                            toggleRow(
                                title: "Ghost by default",
                                subtitle: "Step in invisibly. No notifications fire on arrival.",
                                value: profile?.ghostModeDefault ?? false
                            ) { newValue in
                                Task { await update(ghostDefault: newValue) }
                            }
                        }

                        section(title: "NOTIFICATIONS") {
                            row(label: "Permission", value: notifAuth)
                            divider
                            Button {
                                HapticsService.shared.tap()
                                Task {
                                    await container.notifications.requestAuthorization()
                                    await refreshNotifAuth()
                                }
                            } label: {
                                HStack {
                                    Text("Request notifications")
                                        .font(FTType.body(15, weight: .medium))
                                        .foregroundStyle(FTColor.gold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(FTColor.inkFaint)
                                }
                                .padding(.vertical, FTSpace.sm)
                            }
                            .buttonStyle(.plain)
                        }

                        section(title: "MEMBERSHIP") {
                            row(label: "Status",
                                value: container.entitlements.isPremium ? "Member" : "Free")
                            if container.entitlements.isPremium {
                                if let renews = container.entitlements.renewsAt {
                                    divider
                                    row(label: "Renews",
                                        value: renews.formatted(date: .abbreviated, time: .omitted))
                                }
                            } else {
                                divider
                                Button {
                                    HapticsService.shared.tap()
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        Text("Become a member")
                                            .font(FTType.body(15, weight: .medium))
                                            .foregroundStyle(FTColor.gold)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(FTColor.inkFaint)
                                    }
                                    .padding(.vertical, FTSpace.sm)
                                }
                                .buttonStyle(.plain)
                            }
                            divider
                            Button {
                                Task { try? await container.entitlements.restore() }
                            } label: {
                                HStack {
                                    Text("Restore purchases")
                                        .font(FTType.body(15))
                                        .foregroundStyle(FTColor.inkMuted)
                                    Spacer()
                                }
                                .padding(.vertical, FTSpace.sm)
                            }
                            .buttonStyle(.plain)
                        }

                        section(title: "ABOUT") {
                            row(label: "Version", value: appVersion())
                            if let url = URL(string: "https://thefinalthird.app/privacy") {
                                divider
                                linkRow(label: "Privacy", url: url)
                            }
                            if let url = URL(string: "https://thefinalthird.app/terms") {
                                divider
                                linkRow(label: "Terms", url: url)
                            }
                        }

                        signOutCard

                        if let error {
                            Text(error)
                                .font(FTType.caption(12))
                                .foregroundStyle(FTColor.danger)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, FTSpace.lg)
                    .padding(.top, FTSpace.lg)
                    .padding(.bottom, FTSpace.xxxl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticsService.shared.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                    }
                }
            }
            .toolbarBackground(FTColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) { PaywallView(trigger: "settings") }
            .sheet(isPresented: $showUsual) { TheUsualEditor() }
            .alert("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) {
                    Task { await container.auth.signOut() }
                }
            } message: {
                Text("You'll need to sign in again next time.")
            }
        }
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(FTType.display(34))
                .foregroundStyle(FTColor.gold)
            Text("How you show up.")
                .font(FTType.body(13))
                .foregroundStyle(FTColor.inkMuted)
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // Build the inner view eagerly so FTCard's stored (escaping)
        // body closure captures the resulting View, not the
        // non-escaping input closure parameter.
        let inner = content()
        return VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(title)
                .font(FTType.caption(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(FTColor.inkMuted)
                .padding(.horizontal, FTSpace.md)
            FTCard(padding: FTSpace.lg, texture: .leather, textureIntensity: 0.14) {
                VStack(spacing: 0) {
                    inner
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(FTColor.divider.opacity(0.6))
            .frame(height: 0.5)
            .padding(.vertical, FTSpace.xs)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FTType.caption(11, weight: .medium))
                .tracking(1)
                .foregroundStyle(FTColor.inkMuted)
                .textCase(.uppercase)
            Spacer()
            Text(value)
                .font(FTType.body(14, weight: .medium))
                .foregroundStyle(FTColor.ink)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, FTSpace.sm)
    }

    private func navRow(
        icon: String,
        label: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: FTSpace.md) {
                Image(systemName: icon)
                    .foregroundStyle(FTColor.gold)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(FTType.body(15, weight: .medium))
                        .foregroundStyle(FTColor.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(FTType.caption(11))
                            .foregroundStyle(FTColor.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(FTColor.inkFaint)
            }
            .padding(.vertical, FTSpace.sm)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        value: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(isOn: Binding(
            get: { value },
            set: { onChange($0) }
        )) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(FTType.body(15, weight: .medium))
                    .foregroundStyle(FTColor.ink)
                Text(subtitle)
                    .font(FTType.caption(11))
                    .foregroundStyle(FTColor.inkMuted)
            }
        }
        .tint(FTColor.gold)
        .padding(.vertical, FTSpace.sm)
    }

    private func linkRow(label: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(label)
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(FTColor.inkFaint)
            }
            .padding(.vertical, FTSpace.sm)
        }
    }

    private var signOutCard: some View {
        Button {
            HapticsService.shared.tap()
            showSignOutConfirm = true
        } label: {
            FTCard(texture: nil) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundStyle(FTColor.danger.opacity(0.85))
                    Text("Sign out")
                        .font(FTType.body(15, weight: .medium))
                        .foregroundStyle(FTColor.danger.opacity(0.85))
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

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
