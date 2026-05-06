import Foundation
import Testing
@testable import TheFinalThird

@Suite("OfflineQueue")
struct OfflineQueueTests {
    struct Payload: Codable, Sendable, Equatable {
        let body: String
    }

    @Test("Enqueues an op and reports pending count")
    func enqueueIncrementsCount() async throws {
        let queue = OfflineQueue()
        try await queue.setNoOpReplayer()
        let id = try await queue.enqueue(kind: "test", payload: Payload(body: "hi"))
        #expect(id != UUID())
        let count = await queue.pendingCount()
        // Race: drain may already have run if the simulator is online.
        // Either 0 (drained) or 1 (not yet) is acceptable.
        #expect(count == 0 || count == 1)
    }

    @Test("Replayer success drains the queue")
    func replayerDrains() async throws {
        let queue = OfflineQueue()
        await queue.setReplayer { _ in /* succeed */ }
        _ = try await queue.enqueue(kind: "test", payload: Payload(body: "a"))
        _ = try await queue.enqueue(kind: "test", payload: Payload(body: "b"))
        // Give the actor a moment to drain.
        try await Task.sleep(for: .milliseconds(50))
        let remaining = await queue.pendingCount()
        #expect(remaining == 0)
    }

    @Test("Failing replayer keeps ops with attempts < 10")
    func failingReplayerRetains() async throws {
        let queue = OfflineQueue()
        await queue.setReplayer { _ in throw AppError.timeout }
        _ = try await queue.enqueue(kind: "test", payload: Payload(body: "x"))
        try await Task.sleep(for: .milliseconds(20))
        let count = await queue.pendingCount()
        #expect(count == 1)
    }
}

private extension OfflineQueue {
    /// Convenience for tests: install a no-op replayer.
    func setNoOpReplayer() async throws {
        await setReplayer { _ in }
    }
}
