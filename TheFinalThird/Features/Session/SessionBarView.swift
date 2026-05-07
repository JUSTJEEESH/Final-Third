import SwiftUI

/// Persistent strip pinned at the top of the main tab bar while a
/// cigar is burning. Lets the user navigate the rest of the app —
/// browse rooms, peek at their journal, check the home feed — without
/// losing the burn timer or having to keep the session flow open.
///
/// Tapping the body re-expands the full session screen. The ellipsis
/// opens an action sheet (Open / End). Hidden during the picker /
/// ceremony / summary phases — those own the screen via the cover.
struct SessionBarView: View {
    @Environment(AppContainer.self) private var container
    @State private var showActions = false
    @State private var showEndConfirm = false
    @State private var showSwitchRoom = false

    var body: some View {
        if container.session.isBurning,
           !container.session.isFlowPresented,
           let cigar = container.session.activeCigar,
           let session = container.session.activeSession
        {
            content(cigar: cigar, session: session)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func content(cigar: Cigar, session: Session) -> some View {
        HStack(spacing: FTSpace.md) {
            EmberDot()

            Button {
                HapticsService.shared.tap()
                container.session.expand()
            } label: {
                HStack(spacing: FTSpace.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cigar.brand.uppercased())
                            .font(FTType.caption(9, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(FTColor.gold.opacity(0.85))
                            .lineLimit(1)
                        Text(cigar.line)
                            .font(FTType.body(14, weight: .semibold))
                            .foregroundStyle(FTColor.ink)
                            .lineLimit(1)
                    }
                    Spacer(minLength: FTSpace.sm)
                    BurnTimerLabel(startedAt: session.startedAt)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                HapticsService.shared.tap()
                showActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(FTColor.surfaceHi.opacity(0.7))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Session actions")
        }
        .padding(.horizontal, FTSpace.lg)
        .padding(.vertical, FTSpace.sm)
        .frame(maxWidth: .infinity)
        .background(SessionBarBackground())
        .overlay(alignment: .bottom) {
            // Gold hairline beneath, the same one used to separate
            // toolbars from content elsewhere in the app.
            Rectangle()
                .fill(FTColor.gold.opacity(0.45))
                .frame(height: FTStroke.hairline)
        }
        .confirmationDialog(
            "In session",
            isPresented: $showActions,
            titleVisibility: .hidden
        ) {
            Button("Open session") { container.session.expand() }
            Button("Switch room") {
                // Defer one runloop tick so the dialog dismissal
                // animation finishes before the sheet rises — without
                // this the sheet sometimes refuses to present.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    showSwitchRoom = true
                }
            }
            if container.session.activeRoomID != nil {
                Button("Step out (stay lit)") {
                    Task { await container.session.current?.stepOutKeepLit() }
                }
            }
            Button("End session", role: .destructive) { showEndConfirm = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("End your session?", isPresented: $showEndConfirm) {
            Button("Keep going", role: .cancel) {}
            Button("End it") {
                Task {
                    await container.session.current?.endSession()
                    // Re-open the flow so the summary can be filled in.
                    container.session.expand()
                }
            }
        } message: {
            Text("We'll ask how it was, then it lands in your Journal.")
        }
        .sheet(isPresented: $showSwitchRoom) {
            // Reuse the doorway picker — same component, different
            // moment. Picking a room → moveTo(); picking "Stay solo"
            // → stepOutKeepLit(). Both keep the cigar burning.
            RoomPickerSheet(
                excludeRoomID: container.session.activeRoomID,
                onPick: { room in
                    Task {
                        if let room {
                            await container.session.current?.moveTo(room)
                        } else {
                            await container.session.current?.stepOutKeepLit()
                        }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Pieces

/// Soft pulsing ember to the left of the cigar identity. Signals
/// "alive" without screaming. Three-second breathe matches the
/// glow on the home screen's flame button.
private struct EmberDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [FTColor.ember.opacity(pulse ? 0.55 : 0.30), .clear],
                    center: .center, startRadius: 0,
                    endRadius: pulse ? 14 : 10
                ))
                .frame(width: 28, height: 28)
            Circle()
                .fill(LinearGradient(
                    colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 9, height: 9)
                .shadow(color: FTColor.ember.opacity(0.7), radius: 4)
        }
        .animation(
            .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
            value: pulse
        )
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

/// Live-updating "X min" label. Recomputes once a minute via
/// `TimelineView`, so we don't burn battery for sub-minute precision
/// the user can't read on a 14-pt label anyway.
private struct BurnTimerLabel: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 30)) { context in
            let mins = max(0, Int(context.date.timeIntervalSince(startedAt) / 60))
            HStack(spacing: 4) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 11))
                Text("\(mins) min")
                    .font(FTType.caption(12, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(FTColor.gold)
        }
    }
}

/// Leather grain + soft warm bleed underneath. Same vocabulary as
/// the home Light Up button so the bar feels like an extension of it.
private struct SessionBarBackground: View {
    var body: some View {
        ZStack {
            FTColor.surface
            TexturePanel(texture: .leather, opacity: 0.10, zoom: 1.4)
                .allowsHitTesting(false)
            LinearGradient(
                colors: [FTColor.ember.opacity(0.06), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .horizontal)
    }
}
