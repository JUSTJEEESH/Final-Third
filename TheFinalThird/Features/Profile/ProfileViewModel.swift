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
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in profile = try? await profiles.fetch(id: userID) }
            group.addTask { [self] in usual = try? await usuals.fetch(userID: userID) }
            group.addTask { [self] in connections = (try? await social.connections(userID: userID)) ?? [] }
            group.addTask { [self] in chemistry = (try? await social.chemistry(userID: userID)) ?? [] }
        }
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
