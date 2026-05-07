import Foundation

struct Drink: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var brand: String?
    var name: String
    var category: String
    var subtype: String?
    var imageURL: URL?

    /// Type label shown in the UI (uppercase, e.g. "BEER", "WHISKY").
    var typeLabel: String { category.uppercased() }

    /// Style label — falls back to the category if no subtype is set.
    var styleLabel: String { subtype ?? category.capitalized }
}
