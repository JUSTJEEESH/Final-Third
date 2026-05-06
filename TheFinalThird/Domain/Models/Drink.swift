import Foundation

struct Drink: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var category: String
    var subtype: String?
    var imageURL: URL?
}
