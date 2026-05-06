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
    var selectedStrength: Int?
    var selectedWrapper: String?
    var selectedCountry: String?

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
    }

    func refresh() async {
        isLoading = true; defer { isLoading = false }
        do {
            switch mode {
            case .cigars:
                cigars = try await cigarRepo.search(currentFilters, limit: 100)
            case .drinks:
                drinks = try await drinkRepo.list(category: nil)
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
        Task { await refresh() }
    }

    private func debouncedSearch() async {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    private var currentFilters: CigarFilters {
        CigarFilters(
            query: query,
            country: selectedCountry,
            wrapper: selectedWrapper,
            strength: selectedStrength
        )
    }
}
