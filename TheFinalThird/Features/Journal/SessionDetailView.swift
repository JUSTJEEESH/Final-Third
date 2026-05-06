import SwiftUI

/// A read-only detail page for a completed session. Pulled up from the
/// Journal list. Shows: cigar + drink with detail, when + how long, the
/// ratings the user gave, the mood + unwind state, and any notes they
/// wrote.
///
/// The room/co-attendee information ("who you smoked with") would
/// require an extra query against `sessions` keyed by room_id +
/// overlapping time window — left as a follow-up since it's a separate
/// data fetch.
struct SessionDetailView: View {
    let sessionID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var session: Session?
    @State private var cigar: Cigar?
    @State private var drink: Drink?
    @State private var error: String?

    private let sessionsRepo: SessionRepository = LiveSessionRepository()
    private let cigarsRepo: CigarRepository = LiveCigarRepository()
    private let drinksRepo: DrinkRepository = LiveDrinkRepository()

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FTColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let session, let cigar {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpace.lg) {
                    hero(session: session, cigar: cigar)
                    facts(session: session, drink: drink)
                    if hasRatings(session: session) {
                        ratings(session: session)
                    }
                    moodAndUnwind(session: session)
                    if let notes = session.notes, !notes.isEmpty {
                        notesView(notes: notes)
                    }
                    if session.lightingMethod != nil {
                        lightingView(session: session)
                    }
                }
                .padding(.horizontal, FTSpace.lg)
                .padding(.top, FTSpace.md)
                .padding(.bottom, FTSpace.xxxl)
            }
        } else if let error {
            FTErrorView(message: error) { Task { await load() } }
        } else {
            FTLoadingView(label: "Pulling up your session…")
        }
    }

    // MARK: Sections

    private func hero(session: Session, cigar: Cigar) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(cigar.brand.uppercased())
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.gold)
                .tracking(1.6)
            Text(cigar.line)
                .font(FTType.display(30))
                .foregroundStyle(FTColor.ink)
            if let vitola = cigar.vitola {
                Text(vitola)
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.inkMuted)
            }
            Text(session.startedAt.formatted(date: .complete, time: .shortened))
                .font(FTType.caption(12))
                .foregroundStyle(FTColor.inkFaint)
                .padding(.top, 4)
        }
        .padding(.top, FTSpace.lg)
    }

    private func facts(session: Session, drink: Drink?) -> some View {
        FTCard(elevated: true) {
            VStack(spacing: FTSpace.sm) {
                fact("Duration", value: durationText(for: session))
                Divider().background(FTColor.divider)
                if let drink {
                    fact("Drink", value: drink.name)
                    Divider().background(FTColor.divider)
                }
                fact("Mode", value: session.isGhost ? "Ghost (private)" : "Open")
            }
        }
    }

    private func fact(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .textCase(.uppercase)
            Spacer()
            Text(value)
                .font(FTType.body(14, weight: .medium))
                .foregroundStyle(FTColor.ink)
        }
    }

    private func ratings(session: Session) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Ratings")
            FTCard {
                VStack(spacing: FTSpace.md) {
                    ratingRow("Flavor", value: session.flavorRating)
                    ratingRow("Draw", value: session.drawRating)
                    ratingRow("Overall", value: session.overallRating)
                    if let again = session.wouldSmokeAgain {
                        Divider().background(FTColor.divider)
                        HStack {
                            Image(systemName: again ? "checkmark.circle.fill" : "x.circle.fill")
                                .foregroundStyle(again ? FTColor.gold : FTColor.inkFaint)
                            Text(again ? "I'd smoke this again." : "Probably not again.")
                                .font(FTType.body(14))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func ratingRow(_ label: String, value: Int?) -> some View {
        HStack {
            Text(label)
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted)
                .textCase(.uppercase)
                .frame(width: 80, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: (value ?? 0) >= i ? "star.fill" : "star")
                        .foregroundStyle((value ?? 0) >= i ? FTColor.gold : FTColor.inkFaint)
                        .font(.system(size: 14))
                }
            }
            Spacer()
        }
    }

    private func moodAndUnwind(session: Session) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("How it felt")
            FTCard {
                VStack(alignment: .leading, spacing: FTSpace.md) {
                    if let mood = session.moodScore {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("MOOD")
                                    .font(FTType.caption(10, weight: .semibold))
                                    .foregroundStyle(FTColor.inkMuted)
                                    .tracking(1.4)
                                Spacer()
                                Text("\(mood) / 10")
                                    .font(FTType.bodyMono(13))
                                    .foregroundStyle(FTColor.gold)
                            }
                            moodBar(value: mood)
                        }
                    }
                    if let unwind = session.unwindSuccess {
                        HStack(spacing: FTSpace.sm) {
                            Image(systemName: unwind ? "leaf.fill" : "exclamationmark.bubble")
                                .foregroundStyle(unwind ? FTColor.gold : FTColor.inkMuted)
                            Text(unwind
                                 ? "It helped me unwind."
                                 : "Didn't quite get there.")
                                .font(FTType.body(14))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func moodBar(value: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FTColor.surfaceHi)
                Capsule()
                    .fill(LinearGradient(
                        colors: [FTColor.ember, FTColor.emberHot, FTColor.gold],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * CGFloat(value) / 10)
            }
        }
        .frame(height: 6)
    }

    private func notesView(notes: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Notes")
            FTCard(texture: .agedPaper, textureIntensity: 0.18) {
                Text(notes)
                    .font(FTType.body(15))
                    .foregroundStyle(FTColor.ink.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func lightingView(session: Session) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            sectionTitle("Lighting")
            FTCard {
                HStack(spacing: FTSpace.sm) {
                    if let m = session.lightingMethod {
                        Image(systemName: FlameStyle.forMethod(m).toolSymbol)
                            .foregroundStyle(LinearGradient(
                                colors: [
                                    FlameStyle.forMethod(m).coreColor,
                                    FlameStyle.forMethod(m).bodyColor,
                                    FlameStyle.forMethod(m).outerColor,
                                ],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .font(.system(size: 18))
                        Text(m.displayName).font(FTType.body(15, weight: .medium))
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(FTType.caption(11, weight: .semibold))
            .foregroundStyle(FTColor.inkMuted)
            .tracking(1.2)
    }

    private func hasRatings(session: Session) -> Bool {
        session.flavorRating != nil
            || session.drawRating != nil
            || session.overallRating != nil
            || session.wouldSmokeAgain != nil
    }

    private func durationText(for session: Session) -> String {
        if let mins = session.durationMinutes, mins > 0 {
            let h = mins / 60
            let m = mins % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        if let ended = session.endedAt {
            let mins = Int(ended.timeIntervalSince(session.startedAt) / 60)
            return "\(mins)m"
        }
        return "—"
    }

    private func load() async {
        error = nil
        do {
            let row = try await sessionsRepo.fetch(id: sessionID)
            self.session = row
            if let cigarID = row.cigarID {
                self.cigar = try? await cigarsRepo.fetch(id: cigarID)
            } else {
                self.cigar = Cigar(
                    id: UUID(), brand: "Unknown", line: "Cigar",
                    vitola: nil, country: nil, wrapper: nil, binder: nil,
                    filler: nil, ringGauge: nil, length: nil, strength: nil,
                    flavorNotes: [], originStory: nil, affiliateLink: nil,
                    imageURL: nil, funFact: nil
                )
            }
            if let drinkID = row.drinkID {
                self.drink = try? await drinksRepo.fetch(id: drinkID)
            }
        } catch {
            self.error = "Couldn't load this session: \(error.localizedDescription)"
        }
    }
}
