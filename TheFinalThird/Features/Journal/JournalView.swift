import SwiftUI

struct JournalView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: JournalViewModel?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            if let vm { content(vm) } else { ProgressView().tint(FTColor.gold) }
        }
        .task {
            if vm == nil, case .signedIn(let userID) = container.auth.state {
                vm = JournalViewModel(userID: userID, entitlements: container.entitlements)
                await vm?.load()
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(trigger: "journal_history") }
    }

    @ViewBuilder
    private func content(_ vm: JournalViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Text("Journal")
                    .font(FTType.display(34))
                    .foregroundStyle(FTColor.gold)
                    .padding(.top, FTSpace.md)

                StatsBlock(vm: vm)
                WeeklyRecapBlock(recap: vm.weeklyRecap)

                Text("Recent")
                    .font(FTType.caption(11, weight: .semibold))
                    .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)

                if vm.visibleSessions.isEmpty {
                    EmptyJournal()
                } else {
                    LazyVStack(spacing: FTSpace.sm) {
                        ForEach(vm.visibleSessions) { s in
                            SessionRow(session: s, cigar: s.cigarID.flatMap { vm.cigarsByID[$0] })
                        }
                    }
                }

                if vm.hiddenCount > 0 {
                    PaywallTeaser(hidden: vm.hiddenCount) { showPaywall = true }
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, 96)
        }
    }
}

private struct StatsBlock: View {
    let vm: JournalViewModel

    var body: some View {
        HStack(spacing: FTSpace.md) {
            stat("Sessions", value: "\(vm.totalSessions)")
            stat("Minutes", value: "\(vm.totalMinutes)")
            if let strength = vm.preferredStrength,
               let label = Cigar.Strength(rawValue: strength)?.label {
                stat("Style", value: label)
            }
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(FTType.caption(10, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            Text(value).font(FTType.display(24))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpace.md)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
    }
}

private struct WeeklyRecapBlock: View {
    let recap: WeeklyRecap

    var body: some View {
        FTCard(elevated: true) {
            HStack(spacing: FTSpace.md) {
                Image(systemName: "calendar")
                    .foregroundStyle(FTColor.gold)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
                    if recap.sessionCount == 0 {
                        Text("No sessions yet. There's still time.")
                            .font(FTType.body(15))
                    } else {
                        Text("\(recap.sessionCount) sessions, ~\(recap.averageMinutes) min each.")
                            .font(FTType.body(15))
                    }
                }
                Spacer()
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let cigar: Cigar?

    var body: some View {
        FTCard {
            HStack(spacing: FTSpace.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cigar?.displayName ?? "Cigar")
                        .font(FTType.body(15, weight: .medium))
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                }
                Spacer()
                if let mins = session.durationMinutes {
                    Text("\(mins)m")
                        .font(FTType.bodyMono(13))
                        .foregroundStyle(FTColor.inkMuted)
                }
                if let r = session.overallRating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                        Text("\(r)")
                    }
                    .font(FTType.caption(11))
                    .foregroundStyle(FTColor.gold)
                }
            }
        }
    }
}

private struct EmptyJournal: View {
    var body: some View {
        VStack(spacing: FTSpace.sm) {
            Image(systemName: "book.closed").font(.system(size: 28))
                .foregroundStyle(FTColor.inkFaint)
            Text("Your first session will land here.")
                .font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpace.xxl)
    }
}

private struct PaywallTeaser: View {
    let hidden: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            FTCard {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(FTColor.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(hidden) older sessions are kept for members.")
                            .font(FTType.body(14))
                        Text("Unlock your full journal.")
                            .font(FTType.caption(12))
                            .foregroundStyle(FTColor.gold)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                }
            }
        }.buttonStyle(.plain)
    }
}
