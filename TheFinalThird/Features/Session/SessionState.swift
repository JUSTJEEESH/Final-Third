import Foundation
import Observation

/// Global, observable owner of the active session flow.
///
/// Lives on `AppContainer` so any view in the app can read what's
/// burning right now (`container.session.activeSession`) or react when
/// the user lights up from elsewhere. This is the foundation for the
/// persistent session bar, the post-ceremony "Where are you sitting?"
/// sheet, and the move-between-rooms behavior — none of which can
/// work while the session lives inside one view's `@State`.
///
/// We don't duplicate `SessionViewModel`; we just hoist its ownership
/// here. Views that drive the flow read `current` and bind into it.
/// Views that only need to *observe* (session bar, room presence)
/// read the convenience getters below so they re-render only when the
/// active state changes.
@MainActor
@Observable
final class SessionState {
    /// The view-model driving the in-flight session flow. Non-nil from
    /// "Light up" until the summary is dismissed.
    var current: SessionViewModel?

    /// Whether the full session flow cover is currently on screen.
    /// Bound to a single fullScreenCover in MainTabView so any surface
    /// (Light Up button, session-bar tap, room "Light up here" CTA) can
    /// expand the cover by setting this true. Setting false minimizes —
    /// the session keeps burning in the background and the persistent
    /// session bar takes over.
    var isFlowPresented: Bool = false

    /// True while the cigar is actually burning (post-ceremony,
    /// pre-summary). Used to decide whether to render the session bar.
    var isBurning: Bool {
        guard let phase = current?.phase else { return false }
        return phase == .active
    }

    /// True while *any* session UI is on screen — including pickers,
    /// ceremony, and summary. The session bar should hide during these
    /// because the full flow already owns the screen.
    var isInFlow: Bool { current != nil }

    /// The domain `Session` row, if one has been created (i.e. the
    /// ceremony has completed and we've inserted into Postgres).
    var activeSession: Session? { current?.session }

    var activeCigar: Cigar? { current?.cigar }
    var activeDrink: Drink? { current?.drink }

    /// Room the burning session is currently sitting in. Mutates as the
    /// user moves between rooms mid-session (Step 6 will wire that path;
    /// today this is read-only).
    var activeRoomID: UUID? { current?.session?.roomID }

    /// Begin a new session flow. Idempotent — if a flow is already in
    /// progress, the existing one is preserved so a stray "Light up"
    /// tap from a different surface doesn't reset state.
    func beginFlow(
        userID: UUID,
        roomID: UUID?,
        isGhost: Bool,
        analytics: AnalyticsService
    ) {
        guard current == nil else { return }
        current = SessionViewModel(
            userID: userID,
            roomID: roomID,
            isGhost: isGhost,
            analytics: analytics
        )
    }

    /// Tear down the flow — called when the summary finishes or the
    /// user cancels. Pinned UI listening to `current` will dismiss.
    func clear() {
        current = nil
        isFlowPresented = false
    }

    /// Bring the full session flow back to the front. Used by the
    /// session bar's tap target and any "open session" affordance.
    func expand() {
        guard current != nil else { return }
        isFlowPresented = true
    }

    /// Hide the cover but keep the session running — the user wants to
    /// browse the rest of the app while their cigar continues to burn.
    func minimize() {
        isFlowPresented = false
    }
}
