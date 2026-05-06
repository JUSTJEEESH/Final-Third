import SwiftUI

struct SessionSummaryView: View {
    @Bindable var vm: SessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Text("How was it?")
                    .font(FTType.display(28)).foregroundStyle(FTColor.gold)
                    .padding(.top, FTSpace.lg)

                if let s = vm.session, let mins = s.durationMinutes {
                    Text("\(mins) minutes well spent.")
                        .font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
                }

                rating("Flavor", value: $vm.flavor)
                rating("Draw", value: $vm.draw)
                rating("Overall", value: $vm.overall)

                Toggle("I'd smoke this again.", isOn: $vm.wouldSmokeAgain)
                    .tint(FTColor.gold)

                VStack(alignment: .leading, spacing: FTSpace.xs) {
                    Text("Mood").font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
                    Slider(value: Binding(
                        get: { Double(vm.mood) },
                        set: { vm.mood = Int($0) }
                    ), in: 1 ... 10, step: 1) {
                        Text("Mood")
                    }
                    .tint(FTColor.gold)
                    Text("\(vm.mood) / 10")
                        .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                }

                Toggle("Did this help you unwind?", isOn: $vm.unwind)
                    .tint(FTColor.gold)

                VStack(alignment: .leading, spacing: FTSpace.xs) {
                    Text("Notes").font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
                    TextEditor(text: $vm.notes)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(FTSpace.sm)
                        .background(FTColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                }

                FTButton(title: "Save and step out", style: .gold) {
                    Task { await vm.saveSummary() }
                }
            }
            .padding(.horizontal, FTSpace.xl)
            .padding(.bottom, FTSpace.xxxl)
        }
        .background(FTColor.background)
    }

    private func rating(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.xs) {
            Text(label).font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            HStack(spacing: FTSpace.sm) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= value.wrappedValue ? "star.fill" : "star")
                        .foregroundStyle(i <= value.wrappedValue ? FTColor.gold : FTColor.inkFaint)
                        .font(.system(size: 22))
                        .onTapGesture {
                            HapticsService.shared.tap()
                            value.wrappedValue = i
                        }
                }
            }
        }
    }
}
