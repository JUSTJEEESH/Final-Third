import Foundation

/// Reads Supabase / RevenueCat / LiveKit credentials from `Info.plist`
/// (populated by an .xcconfig that imports a local `Secrets.xcconfig`).
/// The anon key is the only Supabase key allowed on-device per Engineering Rules.
struct SupabaseEnv: Sendable {
    let url: URL
    let anonKey: String
    let liveKitURL: URL
    let revenueCatAPIKey: String

    static let shared: SupabaseEnv = {
        let info = Bundle.main.infoDictionary ?? [:]

        func required(_ key: String) -> String {
            guard let value = info[key] as? String, !value.isEmpty else {
                fatalError("Missing Info.plist key: \(key). Configure Secrets.xcconfig.")
            }
            return value
        }

        guard let url = URL(string: required("SUPABASE_URL")) else {
            fatalError("SUPABASE_URL is not a valid URL.")
        }
        guard let lkURL = URL(string: required("LIVEKIT_URL")) else {
            fatalError("LIVEKIT_URL is not a valid URL.")
        }
        return SupabaseEnv(
            url: url,
            anonKey: required("SUPABASE_ANON_KEY"),
            liveKitURL: lkURL,
            revenueCatAPIKey: required("REVENUECAT_API_KEY_IOS")
        )
    }()
}
