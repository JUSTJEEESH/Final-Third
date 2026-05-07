import Foundation

/// Per-room aggregate served by the `room_live_now` RPC. Used by the
/// "Where are you sitting?" doorway sheet to answer the only question
/// that matters in that moment: who's burning here right now?
///
/// Ghost sessions are filtered server-side — privacy is non-negotiable
/// even at the aggregate level.
struct LiveNowSummary: Hashable, Sendable {
    let roomID: UUID
    let liveCount: Int
    /// Up to three smokers, most recently lit first. The full count
    /// (`liveCount`) may exceed `smokers.count`; the sheet renders
    /// "+N more lit up" beneath the sample.
    let smokers: [Smoker]

    struct Smoker: Hashable, Sendable {
        let userID: UUID
        let displayName: String
        let avatarURL: URL?
        let cigarBrand: String?
        let cigarLine: String?
        let minutesIn: Int

        var cigarDisplay: String? {
            switch (cigarBrand, cigarLine) {
            case let (b?, l?): return "\(b) \(l)"
            case let (b?, nil): return b
            case let (nil, l?): return l
            default: return nil
            }
        }
    }
}
