import Foundation

struct LoungeEvent: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var creatorID: UUID?
    var title: String
    var locationName: String?
    var city: String?
    var datetime: Date?
    var cigarID: UUID?
}

struct EventRSVP: Hashable, Sendable, Codable {
    let eventID: UUID
    let userID: UUID
    var status: Status

    enum Status: String, Sendable, Codable { case going, maybe, declined }
}
