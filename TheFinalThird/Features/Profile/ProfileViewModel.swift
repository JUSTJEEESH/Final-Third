import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var profile: Profile?
    var usual: Usual?
    var connections: [Connection] = []
    var chemistry: [ConnectionChemistry] = []
    var badgeCount: Int = 0
    var error: String?

    private let userID: UUID
    private let profiles: ProfileRepository
    private let usuals: UsualRepository
    private let social: SocialRepository

    init(
        userID: UUID,
        profiles: ProfileRepository = LiveProfileRepository(),
        usuals: UsualRepository = LiveUsualRepository(),
        social: SocialRepository = LiveSocialRepository()
    ) {
        self.userID = userID
        self.profiles = profiles
        self.usuals = usuals
        self.social = social
    }

    func load() async {
        async let p = profiles.fetch(id: userID)
        async let u = usuals.fetch(userID: userID)
        async let c = social.connections(userID: userID)
        async let ch = social.chemistry(userID: userID)

        profile = try? await p
        usual = try? await u
        connections = (try? await c) ?? []
        chemistry = (try? await ch) ?? []
    }

    func updateAudioPref(_ theme: AudioTheme?) async {
        do { try await profiles.updatePreferences(audioTheme: theme, voiceEnabled: nil, ghostModeDefault: nil) }
        catch { self.error = error.localizedDescription }
        profile?.audioTheme = theme
    }

    func updateGhostDefault(_ on: Bool) async {
        do { try await profiles.updatePreferences(audioTheme: nil, voiceEnabled: nil, ghostModeDefault: on) }
        catch { self.error = error.localizedDescription }
        profile?.ghostModeDefault = on
    }
}
