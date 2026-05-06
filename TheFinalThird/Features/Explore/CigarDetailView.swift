import SwiftUI

struct CigarDetailView: View {
    let cigarID: UUID
    @State private var cigar: Cigar?
    @State private var error: String?
    private let repo: CigarRepository

    init(cigarID: UUID, repo: CigarRepository = LiveCigarRepository()) {
        self.cigarID = cigarID
        self.repo = repo
    }

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            if let cigar { content(for: cigar) }
            else if let error { ErrorView(message: error) }
            else { ProgressView().tint(FTColor.gold) }
        }
        .task { await load() }
    }

    private func load() async {
        do { cigar = try await repo.fetch(id: cigarID) }
        catch { self.error = error.localizedDescription }
    }

    @ViewBuilder
    private func content(for cigar: Cigar) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                hero(cigar)
                facts(cigar)
                if let story = cigar.originStory { paragraph("Origin", text: story) }
                if let fact = cigar.funFact { paragraph("Fun fact", text: fact) }
                if !cigar.flavorNotes.isEmpty { flavorRow(notes: cigar.flavorNotes) }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, FTSpace.xxxl)
        }
    }

    private func hero(_ cigar: Cigar) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(cigar.brand.uppercased())
                .font(FTType.caption(12, weight: .semibold))
                .foregroundStyle(FTColor.gold)
                .tracking(1.4)
            Text(cigar.line).font(FTType.display(34))
            if let vitola = cigar.vitola {
                Text(vitola).font(FTType.body(16)).foregroundStyle(FTColor.inkMuted)
            }
        }
        .padding(.top, FTSpace.xxl)
    }

    private func facts(_ cigar: Cigar) -> some View {
        FTCard(elevated: true) {
            VStack(spacing: FTSpace.sm) {
                fact("Country", cigar.country ?? "—")
                Divider().background(FTColor.divider)
                fact("Wrapper", cigar.wrapper ?? "—")
                Divider().background(FTColor.divider)
                fact("Strength", cigar.strength.flatMap { Cigar.Strength(rawValue: $0)?.label } ?? "—")
                if let r = cigar.ringGauge, let l = cigar.length {
                    Divider().background(FTColor.divider)
                    fact("Size", "\(r) × \(String(format: "%.2f", l))″")
                }
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            Spacer()
            Text(value).font(FTType.body(15, weight: .medium))
        }
    }

    private func paragraph(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(title).font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            Text(text).font(FTType.body(15)).foregroundStyle(FTColor.ink.opacity(0.85))
        }
    }

    private func flavorRow(notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("Notes").font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            FlowLayout(spacing: FTSpace.xs) {
                ForEach(notes, id: \.self) { note in
                    Text(note).font(FTType.caption(12, weight: .medium))
                        .padding(.horizontal, FTSpace.sm).padding(.vertical, 6)
                        .background(FTColor.surfaceHi)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct ErrorView: View {
    let message: String
    var body: some View {
        Text(message).font(FTType.body(14)).foregroundStyle(FTColor.danger)
    }
}

/// Lightweight flow layout — wraps children onto multiple rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX; var y: CGFloat = bounds.minY; var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
