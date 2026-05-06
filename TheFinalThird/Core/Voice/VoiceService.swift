import Foundation
import LiveKit

/// Wraps LiveKit room session for voice rooms (PRD §7 — push-to-talk + live).
/// Tokens are issued by a Supabase edge function (`livekit-token`) which
/// validates membership and entitlement.
@MainActor
@Observable
final class VoiceService {
    enum Mode: Sendable { case off, pushToTalk, alwaysOn }

    private(set) var mode: Mode = .off
    private(set) var isTransmitting: Bool = false
    private(set) var participants: [String] = []

    private let room = Room()
    private let env = SupabaseEnv.shared

    init() {}

    func join(roomID: UUID, asSpeaker: Bool, tokenProvider: @Sendable (UUID) async throws -> String) async throws {
        let token = try await tokenProvider(roomID)
        try await room.connect(url: env.liveKitURL.absoluteString, token: token)
        let lp = room.localParticipant
        try await lp.setMicrophone(enabled: false) // start muted
        mode = asSpeaker ? .pushToTalk : .off
    }

    func leave() async {
        await room.disconnect()
        mode = .off
        isTransmitting = false
    }

    /// Hold-to-talk: enable mic on press, disable on release.
    func setTransmitting(_ on: Bool) async {
        guard mode != .off else { return }
        do {
            try await room.localParticipant.setMicrophone(enabled: on)
            isTransmitting = on
        } catch {
            isTransmitting = false
        }
    }

    func setMode(_ mode: Mode) async {
        self.mode = mode
        if mode == .alwaysOn {
            try? await room.localParticipant.setMicrophone(enabled: true)
            isTransmitting = true
        } else {
            try? await room.localParticipant.setMicrophone(enabled: false)
            isTransmitting = false
        }
    }
}
