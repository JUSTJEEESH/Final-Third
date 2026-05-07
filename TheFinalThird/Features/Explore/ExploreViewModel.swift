import Foundation
import Observation

@MainActor
@Observable
final class ExploreViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case cigars, drinks
        var id: Self { self }
        var label: String { rawValue.capitalized }
    }

    var mode: Mode = .cigars
    var query: String = "" { didSet { Task { await debouncedSearch() } } }

    // Cigar filters
    var selectedStrength: Int?
    var selectedWrapper: String?
    var selectedCountry: String?

    // Drink filters
    var selectedDrinkCategory: String? {
        didSet {
            // When the category changes, reset brand and reload the brand
            // list scoped to the new category.
            if oldValue != selectedDrinkCategory {
                selectedDrinkBrand = nil
                Task { await loadBrands() }
            }
        }
    }
    var selectedDrinkBrand: String?
    var selectedDrinkSubtype: String?
    private(set) var availableDrinkCategories: [String] = []
    private(set) var availableDrinkBrands: [String] = []

    private(set) var cigars: [Cigar] = []
    private(set) var drinks: [Drink] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    private let cigarRepo: CigarRepository
    private let drinkRepo: DrinkRepository
    private var searchTask: Task<Void, Never>?

    init(
        cigarRepo: CigarRepository = LiveCigarRepository(),
        drinkRepo: DrinkRepository = LiveDrinkRepository()
    ) {
        self.cigarRepo = cigarRepo
        self.drinkRepo = drinkRepo
    }

    func load() async {
        await refresh()
        if availableDrinkCategories.isEmpty {
            availableDrinkCategories = (try? await drinkRepo.categories()) ?? []
        }
        await loadBrands()
    }

    func loadBrands() async {
        availableDrinkBrands =
            (try? await drinkRepo.brands(forCategory: selectedDrinkCategory)) ?? []
    }

    func refresh() async {
        isLoading = true; defer { isLoading = false }
        do {
            switch mode {
            case .cigars:
                cigars = try await cigarRepo.search(currentCigarFilters, limit: 200)
            case .drinks:
                drinks = try await drinkRepo.search(currentDrinkFilters, limit: 500)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
        Task { await refresh() }
    }

    func clearFilters() {
        selectedStrength = nil
        selectedWrapper = nil
        selectedCountry = nil
        selectedDrinkCategory = nil
        selectedDrinkBrand = nil
        selectedDrinkSubtype = nil
        Task {
            await loadBrands()
            await refresh()
        }
    }

    private func debouncedSearch() async {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    private var currentCigarFilters: CigarFilters {
        CigarFilters(
            query: query,
            country: selectedCountry,
            wrapper: selectedWrapper,
            strength: selectedStrength
        )
    }

    private var currentDrinkFilters: DrinkFilters {
        DrinkFilters(
            query: query,
            category: selectedDrinkCategory,
            brand: selectedDrinkBrand,
            subtype: selectedDrinkSubtype.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
