import Foundation
import Network

/// Queues mutations performed while offline. Replays them in order when the
/// network returns. Each op carries an idempotency key so the server can
/// safely deduplicate retries.
actor OfflineQueue {
    struct Op: Codable, Identifiable, Sendable {
        let id: UUID
        let kind: String     // e.g. "session.create", "message.send"
        let payload: Data    // JSON-encoded
        let createdAt: Date
        var attempts: Int
    }

    typealias Replayer = @Sendable (Op) async throws -> Void

    private var queue: [Op] = []
    private let storeURL: URL
    private let monitor = NWPathMonitor()
    private var isOnline = true
    private var replayer: Replayer?

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storeURL = dir.appendingPathComponent("offline_queue.json")
        Task { await load() }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handlePath(satisfied: path.status == .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    func setReplayer(_ replayer: @escaping Replayer) {
        self.replayer = replayer
    }

    func enqueue<P: Encodable & Sendable>(kind: String, payload: P) async throws -> UUID {
        let data = try JSONEncoder().encode(payload)
        let op = Op(id: UUID(), kind: kind, payload: data, createdAt: .now, attempts: 0)
        queue.append(op)
        await persist()
        if isOnline { Task { await drain() } }
        return op.id
    }

    func pendingCount() -> Int { queue.count }

    // MARK: Internal

    private func handlePath(satisfied: Bool) async {
        isOnline = satisfied
        if satisfied { await drain() }
    }

    private func drain() async {
        guard let replayer else { return }
        var remaining: [Op] = []
        for var op in queue {
            do {
                try await replayer(op)
            } catch {
                op.attempts += 1
                if op.attempts < 10 {
                    remaining.append(op)
                }
            }
        }
        queue = remaining
        await persist()
    }

    private func load() async {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        queue = (try? JSONDecoder().decode([Op].self, from: data)) ?? []
    }

    private func persist() async {
        let data = (try? JSONEncoder().encode(queue)) ?? Data()
        try? data.write(to: storeURL, options: .atomic)
    }
}
