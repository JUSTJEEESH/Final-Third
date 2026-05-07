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
    /// Uploads JPEG data to `avatars/<userID>/avatar.jpg`, updates the
    /// user's `avatar_url`, and returns the cache-busted public URL.
    func uploadAvatar(data: Data, userID: UUID) async throws -> URL
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

    func uploadAvatar(data: Data, userID: UUID) async throws -> URL {
        // Path must use the lowercase UUID — Postgres `auth.uid()::text`
        // is lowercase, and the avatars_insert_own RLS policy compares
        // it against `(storage.foldername(name))[1]` as a plain string.
        // Swift's UUID.uuidString returns uppercase, so without
        // .lowercased() the storage write fails with
        // "new row violates row-level security policy".
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        let storage = client.storage.from("avatars")

        // upsert: true so re-uploads replace the existing avatar at this
        // path. Bucket is public (migration 0008) so no signed URL needed
        // for display.
        _ = try await storage.upload(
            path,
            data: data,
            options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            )
        )

        // Cache-bust the public URL with a `v=<timestamp>` query so
        // AsyncImage refreshes when the user uploads a new photo. The
        // storage URL itself is stable; clients key their image cache by
        // the full URL string.
        let publicURL = try storage.getPublicURL(path: path)
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "v", value: String(Int(Date.now.timeIntervalSince1970))),
        ]
        let bustedURL = components?.url ?? publicURL

        struct Patch: Encodable { let avatar_url: String }
        try await client.from("profiles")
            .update(Patch(avatar_url: bustedURL.absoluteString))
            .eq("id", value: userID.uuidString)
            .execute()

        return bustedURL
    }
}
