import Foundation
import Supabase

/// Configures the Supabase client used app-wide. Realtime is enabled and the
/// auth listener is wired in `AuthService`.
extension SupabaseClient {
    static let live: SupabaseClient = {
        let env = SupabaseEnv.shared
        return SupabaseClient(
            supabaseURL: env.url,
            supabaseKey: env.anonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                auth: .init(
                    storage: KeychainAuthStorage(),
                    flowType: .pkce
                ),
                global: .init(headers: ["X-Client": "ios-final-third"]),
                realtime: .init(timeoutInterval: 10)
            )
        )
    }()
}
