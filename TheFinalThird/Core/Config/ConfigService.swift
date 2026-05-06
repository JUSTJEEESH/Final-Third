import Foundation
import Supabase

/// Reads `app_config` rows with TTL caching. Used for server-driven copy,
/// featured cigar, ambient theme list, etc.
@MainActor
@Observable
final class ConfigService {
    private(set) var values: [String: AnyDecodable] = [:]
    private(set) var lastFetchedAt: Date?

    private let client: SupabaseClient
    private let ttl: TimeInterval = 15 * 60

    init(client: SupabaseClient = .live) {
        self.client = client
    }

    func value<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
        values[key]?.decode(as: type)
    }

    func string(_ key: String) -> String? { value(key, as: String.self) }

    func refreshIfStale() async {
        if let lastFetchedAt, Date.now.timeIntervalSince(lastFetchedAt) < ttl { return }
        await refresh()
    }

    func refresh() async {
        do {
            let rows: [Row] = try await client
                .from("app_config")
                .select()
                .execute()
                .value
            var map: [String: AnyDecodable] = [:]
            for row in rows { map[row.key] = AnyDecodable(row.value) }
            values = map
            lastFetchedAt = .now
        } catch {
            // Keep last known values; never crash on config fetch.
        }
    }

    private struct Row: Decodable {
        let key: String
        let value: AnyDecodable
    }
}

/// Type-erased JSON value for `app_config.value` jsonb column.
struct AnyDecodable: Decodable, Sendable {
    let raw: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { raw = v; return }
        if let v = try? container.decode(Bool.self) { raw = v; return }
        if let v = try? container.decode(Double.self) { raw = v; return }
        if let v = try? container.decode([AnyDecodable].self) { raw = v.map(\.raw); return }
        if let v = try? container.decode([String: AnyDecodable].self) {
            raw = v.mapValues(\.raw); return
        }
        raw = NSNull()
    }

    init(_ raw: Any) { self.raw = raw }

    func decode<T: Decodable>(as type: T.Type) -> T? {
        if let direct = raw as? T { return direct }
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.fragmentsAllowed]) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
}
