import SwiftUI

@MainActor
@Observable
final class TheUsualEditorViewModel {
    var enabled: Bool = true
    var time: Date = Calendar.current.date(
        bySettingHour: 21, minute: 0, second: 0, of: .now
    ) ?? .now
    var cigar: Cigar?
    var drink: Drink?

    var cigars: [Cigar] = []
    var drinks: [Drink] = []
    var isWorking = false
    var error: String?

    private let userID: UUID
    private let usuals: UsualRepository
    private let cigarsRepo: CigarRepository
    private let drinksRepo: DrinkRepository
    private let notifications: NotificationService

    init(
        userID: UUID,
        usuals: UsualRepository = LiveUsualRepository(),
        cigars: CigarRepository = LiveCigarRepository(),
        drinks: DrinkRepository = LiveDrinkRepository(),
        notifications: NotificationService
    ) {
        self.userID = userID
        self.usuals = usuals
        self.cigarsRepo = cigars
        self.drinksRepo = drinks
        self.notifications = notifications
    }

    func load() async {
        async let usual = (try? await usuals.fetch(userID: userID))
        async let cigarsTask = (try? await cigarsRepo.search(.init(), limit: 200)) ?? []
        async let drinksTask = (try? await drinksRepo.list(category: nil)) ?? []
        cigars = await cigarsTask
        drinks = await drinksTask
        if let u = await usual {
            enabled = u.enabled
            if let t = u.preferredTime {
                time = Calendar.current.date(
                    bySettingHour: t.hour, minute: t.minute, second: 0, of: .now
                ) ?? time
            }
            cigar = u.cigarID.flatMap { id in cigars.first { $0.id == id } }
            drink = u.drinkID.flatMap { id in drinks.first { $0.id == id } }
        }
    }

    func save() async -> Bool {
        isWorking = true; defer { isWorking = false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let tod = TimeOfDay(hour: comps.hour ?? 21, minute: comps.minute ?? 0)
        do {
            try await usuals.upsert(
                userID: userID,
                time: tod,
                cigarID: cigar?.id,
                drinkID: drink?.id,
                enabled: enabled
            )
            if enabled {
                await notifications.scheduleUsual(at: tod)
            } else {
                notifications.cancelUsual()
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

struct TheUsualEditor: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TheUsualEditorViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                FTColor.background.ignoresSafeArea()
                if let vm { content(vm) } else { ProgressView().tint(FTColor.gold) }
            }
            .navigationTitle("Your Usual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await vm?.save() == true { dismiss() }
                        }
                    }
                    .disabled(vm?.isWorking ?? false)
                    .tint(FTColor.gold)
                }
            }
        }
        .task {
            if vm == nil, case .signedIn(let userID) = container.auth.state {
                vm = TheUsualEditorViewModel(
                    userID: userID,
                    notifications: container.notifications
                )
                await vm?.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: TheUsualEditorViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FTSpace.lg) {
                Text("Pick a time. We'll pour the room.")
                    .font(FTType.body(14)).foregroundStyle(FTColor.inkMuted)
                    .padding(.top, FTSpace.md)

                FTCard {
                    Toggle("Remind me", isOn: Bindable(vm).enabled).tint(FTColor.gold)
                }

                FTCard {
                    DatePicker(
                        "When",
                        selection: Bindable(vm).time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity)

                section("Default cigar") {
                    cigarPicker(vm: vm)
                }
                section("Default drink") {
                    drinkPicker(vm: vm)
                }

                if let error = vm.error {
                    Text(error).font(FTType.caption(12)).foregroundStyle(FTColor.danger)
                }
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.bottom, FTSpace.xxxl)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text(title).font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
            content()
        }
    }

    private func cigarPicker(vm: TheUsualEditorViewModel) -> some View {
        Menu {
            Button("None") { vm.cigar = nil }
            ForEach(vm.cigars) { c in
                Button(c.displayName) { vm.cigar = c }
            }
        } label: {
            FTCard {
                HStack {
                    Text(vm.cigar?.displayName ?? "Choose a cigar")
                        .font(FTType.body(15))
                        .foregroundStyle(vm.cigar == nil ? FTColor.inkMuted : FTColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
    }

    private func drinkPicker(vm: TheUsualEditorViewModel) -> some View {
        Menu {
            Button("None") { vm.drink = nil }
            ForEach(vm.drinks) { d in
                Button(d.name) { vm.drink = d }
            }
        } label: {
            FTCard {
                HStack {
                    Text(vm.drink?.name ?? "Choose a drink")
                        .font(FTType.body(15))
                        .foregroundStyle(vm.drink == nil ? FTColor.inkMuted : FTColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
    }
}
