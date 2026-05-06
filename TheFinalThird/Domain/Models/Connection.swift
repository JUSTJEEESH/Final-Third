import Foundation

struct Connection: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var requesterID: UUID
    var addresseeID: UUID
    var status: Status
    var createdAt: Date

    enum Status: String, Sendable, Codable { case pending, accepted, declined, blocked }
}

struct ConnectionChemistry: Hashable, Sendable, Codable {
    let userA: UUID
    let userB: UUID
    var sessionsTogether: Int
    var minutesTogether: Int
    var lastSessionAt: Date?
}
