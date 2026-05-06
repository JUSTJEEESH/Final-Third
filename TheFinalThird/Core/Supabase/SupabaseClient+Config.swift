import Foundation
import Supabase

/// Configures the Supabase client used app-wide.
///
/// NOTE: configuration is intentionally minimal. We're stripped to the
/// vanilla `SupabaseClient(url:key:)` init while we sort out an SDK-side
/// crash during email signup (NSJSONSerialization throws on a
/// `__SwiftValue` somewhere in the auth/realtime stack with our custom
/// options). Once first-run is verified end-to-end, layer back:
///   - `auth.storage = KeychainAuthStorage()` for persistent sessions
///     (otherwise sessions live in UserDefaults and survive uninstall in
///     a worse way)
///   - `auth.flowType = .pkce` if we want the PKCE flow on Apple SIWA
///   - `global.headers = ["X-Client": "ios-final-third"]` for telemetry
extension SupabaseClient {
    static let live: SupabaseClient = {
        let env = SupabaseEnv.shared
        return SupabaseClient(supabaseURL: env.url, supabaseKey: env.anonKey)
    }()
}
