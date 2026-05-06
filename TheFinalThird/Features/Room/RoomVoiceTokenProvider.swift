import Foundation
import Supabase

/// Calls the `livekit-token` Supabase edge function to get a room-scoped
/// JWT for the current user. The function runs in `supabase/functions/`.
struct RoomVoiceTokenProvider {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func token(forRoom roomID: UUID) async throws -> String {
        struct Body: Encodable { let room_id: UUID }
        struct Response: Decodable { let token: String }

        let response: Response = try await client.functions
            .invoke("livekit-token", options: .init(body: Body(room_id: roomID)))
        return response.token
    }
}
