import SwiftUI

struct ExploreView: View {
    @State private var vm = ExploreViewModel()
    @State private var showFilters = false
    @State private var showSubmitCigar = false
    @State private var showSubmitDrink = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                FTColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    modePicker
                    searchField
                    content
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                if case let .cigar(id) = route { CigarDetailView(cigarID: id) }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showFilters) { FiltersSheet(vm: vm) }
        .sheet(isPresented: $showSubmitCigar) { SubmitCigarView() }
        .sheet(isPresented: $showSubmitDrink) { SubmitDrinkView() }
    }

    private var header: some View {
        HStack {
            Text("Explore").font(FTType.display(32)).foregroundStyle(FTColor.gold)
            Spacer()
            Button { showFilters = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(FTColor.gold)
                    .padding(FTSpace.sm)
                    .background(FTColor.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, FTSpace.lg)
        .padding(.top, FTSpace.lg)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ExploreViewModel.Mode.allCases) { mode in
                Button { vm.setMode(mode) } label: {
                    Text(mode.label)
                        .font(FTType.body(14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FTSpace.sm)
                        .foregroundStyle(vm.mode == mode ? FTColor.inkInverse : FTColor.inkMuted)
                        .background(vm.mode == mode ? FTColor.gold : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(FTColor.surface)
        .clipShape(Capsule())
        .padding(.horizontal, FTSpace.lg)
        .padding(.top, FTSpace.md)
    }

    private var searchField: some View {
        HStack(spacing: FTSpace.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(FTColor.inkMuted)
            TextField("", text: Bindable(vm).query, prompt: Text("Search cigars, drinks…")
                .foregroundColor(FTColor.inkFaint))
                .foregroundStyle(FTColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(FTSpace.md)
        .background(FTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
        .padding(.horizontal, FTSpace.lg)
        .padding(.top, FTSpace.md)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView().tint(FTColor.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch vm.mode {
            case .cigars: cigarsList
            case .drinks: drinksList
            }
        }
    }

    private var cigarsList: some View {
        ScrollView {
            LazyVStack(spacing: FTSpace.sm) {
                ForEach(vm.cigars) { cigar in
                    NavigationLink(value: AppRoute.cigar(cigar.id)) {
                        CigarRow(cigar: cigar)
                    }.buttonStyle(.plain)
                }
                if vm.cigars.isEmpty {
                    Text("Nothing matches that search.")
                        .font(FTType.caption(13)).foregroundStyle(FTColor.inkMuted)
                        .padding(.top, FTSpace.xl)
                }
                addCigarRow
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.top, FTSpace.lg)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private var addCigarRow: some View {
        Button {
            HapticsService.shared.tap()
            showSubmitCigar = true
        } label: {
            FTCard(texture: nil) {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(FTColor.gold)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Don't see your cigar?")
                            .font(FTType.body(14, weight: .medium))
                        Text("Submit it for the catalog.")
                            .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, FTSpace.md)
    }

    private var drinksList: some View {
        ScrollView {
            LazyVStack(spacing: FTSpace.sm) {
                ForEach(vm.drinks) { drink in
                    DrinkRow(drink: drink)
                }
                if vm.drinks.isEmpty {
                    Text("Nothing matches that search.")
                        .font(FTType.caption(13)).foregroundStyle(FTColor.inkMuted)
                        .padding(.top, FTSpace.xl)
                }
                addDrinkRow
            }
            .padding(.horizontal, FTSpace.lg)
            .padding(.top, FTSpace.lg)
            .padding(.bottom, FTSpace.lg)
        }
    }

    private var addDrinkRow: some View {
        Button {
            HapticsService.shared.tap()
            showSubmitDrink = true
        } label: {
            FTCard(texture: nil) {
                HStack(spacing: FTSpace.md) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(FTColor.gold)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Don't see your drink?")
                            .font(FTType.body(14, weight: .medium))
                        Text("Submit it for the bar.")
                            .font(FTType.caption(11)).foregroundStyle(FTColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(FTColor.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, FTSpace.md)
    }
}

private struct CigarRow: View {
    let cigar: Cigar
    var body: some View {
        FTCard {
            HStack(spacing: FTSpace.md) {
                CigarThumb(url: cigar.imageURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cigar.brand).font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted).textCase(.uppercase)
                    Text(cigar.line).font(FTType.body(16, weight: .medium))
                    if let v = cigar.vitola {
                        Text(v).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                    }
                    if let s = cigar.strength, let label = Cigar.Strength(rawValue: s)?.label {
                        Text(label).font(FTType.caption(11))
                            .foregroundStyle(FTColor.gold)
                    }
                }
                Spacer()
            }
        }
    }
}

private struct DrinkRow: View {
    let drink: Drink
    var body: some View {
        FTCard {
            HStack(spacing: FTSpace.md) {
                CigarThumb(url: drink.imageURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(drink.category.uppercased())
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.inkMuted)
                    Text(drink.name).font(FTType.body(16, weight: .medium))
                    if let s = drink.subtype {
                        Text(s).font(FTType.caption(12)).foregroundStyle(FTColor.inkMuted)
                    }
                }
                Spacer()
            }
        }
    }
}

private struct CigarThumb: View {
    let url: URL?
    var body: some View {
        ZStack {
            FTColor.surfaceHi
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() }
                }
            } else {
                Image(systemName: "leaf").foregroundStyle(FTColor.inkFaint)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: FTRadius.sm))
    }
}

private struct FiltersSheet: View {
    @Bindable var vm: ExploreViewModel
    @Environment(\.dismiss) private var dismiss

    private static let cigarWrappers = [
        "Connecticut", "Habano", "Maduro", "Corojo", "Sumatra",
        "Cameroon", "Broadleaf", "Sun Grown", "San Andrés",
    ]
    private static let cigarCountries = [
        "Cuba", "Nicaragua", "Honduras", "Dominican Republic",
        "Mexico", "Brazil", "Ecuador", "USA",
    ]
    /// Categories shown in the drink filter. Driven by the live catalog
    /// distinct values from ExploreViewModel.availableDrinkCategories;
    /// fall back to a static list if that fetch hasn't completed yet.
    private static let fallbackDrinkCategories = [
        "whisky", "beer", "rum", "tequila", "mezcal", "cognac",
        "armagnac", "port", "sherry", "madeira", "amaro",
        "coffee", "tea", "non-alcoholic",
    ]

    var body: some View {
        NavigationStack {
            Form {
                if vm.mode == .cigars {
                    cigarSections
                } else {
                    drinkSections
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { vm.clearFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { await vm.refresh() }
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var cigarSections: some View {
        Section("Strength") {
            Picker("Strength", selection: $vm.selectedStrength) {
                Text("Any").tag(Int?.none)
                ForEach(1...5, id: \.self) { s in
                    Text(Cigar.Strength(rawValue: s)?.label ?? "\(s)").tag(Int?.some(s))
                }
            }
        }
        Section("Wrapper") {
            Picker("Wrapper", selection: $vm.selectedWrapper) {
                Text("Any").tag(String?.none)
                ForEach(Self.cigarWrappers, id: \.self) {
                    Text($0).tag(String?.some($0))
                }
            }
        }
        Section("Country") {
            Picker("Country", selection: $vm.selectedCountry) {
                Text("Any").tag(String?.none)
                ForEach(Self.cigarCountries, id: \.self) {
                    Text($0).tag(String?.some($0))
                }
            }
        }
    }

    @ViewBuilder
    private var drinkSections: some View {
        Section("Category") {
            Picker("Category", selection: $vm.selectedDrinkCategory) {
                Text("Any").tag(String?.none)
                ForEach(drinkCategoryOptions, id: \.self) { c in
                    Text(c.capitalized).tag(String?.some(c))
                }
            }
        }
        Section("Subtype") {
            TextField("e.g. Belgian Quadrupel, Islay single malt",
                      text: Binding(
                          get: { vm.selectedDrinkSubtype ?? "" },
                          set: { vm.selectedDrinkSubtype = $0.isEmpty ? nil : $0 }
                      ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Free text — partial match against existing entries.")
                .font(FTType.caption(11))
                .foregroundStyle(FTColor.inkMuted)
        }
    }

    private var drinkCategoryOptions: [String] {
        vm.availableDrinkCategories.isEmpty
            ? Self.fallbackDrinkCategories
            : vm.availableDrinkCategories
    }
}
