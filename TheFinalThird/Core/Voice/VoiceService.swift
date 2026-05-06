import Foundation
import LiveKit

/// Wraps a LiveKit room for voice rooms (PRD §7 — push-to-talk + live).
///
/// NOTE: stubbed for now. The LiveKit Swift SDK `Room` initializer surface
/// changed in 2.x (was `Room()`, now requires keyword args in some
/// minor versions). Until we pin and verify the exact resolved version,
/// these methods are no-ops so the app builds and the rest of the
/// experience runs. Wire up against the chosen SDK version in a follow-up.
@MainActor
@Observable
final class VoiceService {
    enum Mode: Sendable { case off, pushToTalk, alwaysOn }

    private(set) var mode: Mode = .off
    private(set) var isTransmitting: Bool = false
    private(set) var participants: [String] = []

    init() {}

    func join(
        roomID: UUID,
        asSpeaker: Bool,
        tokenProvider: @Sendable (UUID) async throws -> String
    ) async throws {
        // Token is fetched so we exercise the edge function path even
        // before LiveKit is wired up.
        _ = try await tokenProvider(roomID)
        mode = asSpeaker ? .pushToTalk : .off
    }

    func leave() async {
        mode = .off
        isTransmitting = false
    }

    func setTransmitting(_ on: Bool) async {
        guard mode != .off else { return }
        isTransmitting = on
    }

    func setMode(_ mode: Mode) async {
        self.mode = mode
        isTransmitting = mode == .alwaysOn
    }
}
