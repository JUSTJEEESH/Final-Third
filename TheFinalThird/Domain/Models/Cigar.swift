import Foundation

struct Cigar: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var brand: String
    var line: String
    var vitola: String?
    var country: String?
    var wrapper: String?
    var binder: String?
    var filler: String?
    var ringGauge: Int?
    var length: Double?
    var strength: Int?      // 1...5
    var flavorNotes: [String]
    var originStory: String?
    var affiliateLink: URL?
    var imageURL: URL?
    var funFact: String?

    var displayName: String { "\(brand) \(line)" }
}

extension Cigar {
    enum Strength: Int, CaseIterable {
        case mild = 1, mildMedium, medium, mediumFull, full

        var label: String {
            switch self {
            case .mild: return "Mild"
            case .mildMedium: return "Mild–Medium"
            case .medium: return "Medium"
            case .mediumFull: return "Medium–Full"
            case .full: return "Full"
            }
        }
    }
}
