import SwiftUI

@MainActor
@Observable
final class EventsViewModel {
    var events: [LoungeEvent] = []
    var isLoading = false
    var error: String?

    private let repo: EventRepository
    init(repo: EventRepository = LiveEventRepository()) { self.repo = repo }

    func load(city: String?) async {
        isLoading = true; defer { isLoading = false }
        do { events = try await repo.upcoming(city: city, limit: 50) }
        catch { self.error = error.localizedDescription }
    }

    func rsvp(eventID: UUID, status: EventRSVP.Status) async {
        do { try await repo.rsvp(eventID: eventID, status: status) }
        catch { self.error = error.localizedDescription }
    }
}

struct EventsView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm = EventsViewModel()

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            content
        }
        .task { await vm.load(city: nil) }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView().tint(FTColor.gold)
        } else if vm.events.isEmpty {
            VStack(spacing: FTSpace.sm) {
                Image(systemName: "calendar").font(.system(size: 28))
                    .foregroundStyle(FTColor.inkFaint)
                Text("No events on the calendar.")
                    .font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
                Text("Create one for your city.")
                    .font(FTType.caption(12)).foregroundStyle(FTColor.inkFaint)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: FTSpace.sm) {
                    ForEach(vm.events) { event in
                        EventRow(event: event) { status in
                            Task { await vm.rsvp(eventID: event.id, status: status) }
                        }
                    }
                }
                .padding(.horizontal, FTSpace.lg)
                .padding(.vertical, FTSpace.lg)
            }
        }
    }
}

private struct EventRow: View {
    let event: LoungeEvent
    let onRSVP: (EventRSVP.Status) -> Void

    var body: some View {
        FTCard {
            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text(event.title).font(FTType.body(16, weight: .semibold))
                if let when = event.datetime {
                    Text(when.formatted(date: .abbreviated, time: .shortened))
                        .font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                }
                if let where_ = event.locationName {
                    Text(where_).font(FTType.caption(12)).foregroundStyle(FTColor.inkFaint)
                }
                HStack(spacing: FTSpace.sm) {
                    rsvpButton("Going", status: .going, primary: true)
                    rsvpButton("Maybe", status: .maybe, primary: false)
                }
            }
        }
    }

    private func rsvpButton(_ label: String, status: EventRSVP.Status, primary: Bool) -> some View {
        Button {
            HapticsService.shared.tap()
            onRSVP(status)
        } label: {
            Text(label)
                .font(FTType.caption(12, weight: .semibold))
                .padding(.horizontal, FTSpace.md)
                .padding(.vertical, FTSpace.sm)
                .background(primary ? FTColor.gold : FTColor.surface)
                .foregroundStyle(primary ? FTColor.inkInverse : FTColor.ink)
                .clipShape(Capsule())
        }
    }
}
