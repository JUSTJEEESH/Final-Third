import Foundation
import Supabase

protocol ProfileRepository: Sendable {
    func fetch(id: UUID) async throws -> Profile
    func upsert(_ profile: Profile) async throws
    func updatePreferences(
        audioTheme: AudioTheme?,
        voiceEnabled: Bool?,
        ghostModeDefault: Bool?
    ) async throws
}

struct LiveProfileRepository: ProfileRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func fetch(id: UUID) async throws -> Profile {
        let dto: DTO.Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    func upsert(_ profile: Profile) async throws {
        struct Insert: Encodable {
            let id: UUID
            let display_name: String
            let handle: String?
            let avatar_url: String?
            let bio: String?
            let city: String?
            let is_honduras_local: Bool
            let audio_theme: String?
            let voice_enabled: Bool
            let ghost_mode_default: Bool
            let timezone: String?
        }
        let row = Insert(
            id: profile.id,
            display_name: profile.displayName,
            handle: profile.handle,
            avatar_url: profile.avatarURL?.absoluteString,
            bio: profile.bio,
            city: profile.city,
            is_honduras_local: profile.isHondurasLocal,
            audio_theme: profile.audioTheme?.rawValue,
            voice_enabled: profile.voiceEnabled,
            ghost_mode_default: profile.ghostModeDefault,
            timezone: profile.timezone
        )
        try await client.from("profiles").upsert(row).execute()
    }

    func updatePreferences(
        audioTheme: AudioTheme?,
        voiceEnabled: Bool?,
        ghostModeDefault: Bool?
    ) async throws {
        guard let userID = try await client.auth.session.user.id as UUID? else {
            throw AppError.notAuthenticated
        }
        struct Patch: Encodable {
            var audio_theme: String??
            var voice_enabled: Bool?
            var ghost_mode_default: Bool?
        }
        let patch = Patch(
            audio_theme: audioTheme.map { .some($0.rawValue) },
            voice_enabled: voiceEnabled,
            ghost_mode_default: ghostModeDefault
        )
        try await client.from("profiles")
            .update(patch)
            .eq("id", value: userID.uuidString)
            .execute()
    }
}
