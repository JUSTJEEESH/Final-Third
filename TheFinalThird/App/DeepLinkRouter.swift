import Foundation

/// Parses incoming URLs into typed routes. Used by the root scene.
enum AppRoute: Hashable, Sendable {
    case home
    case room(UUID)
    case cigar(UUID)
    case drop(UUID)
    case theUsual
    case profile(UUID)
    case session(UUID)
}

@MainActor
@Observable
final class DeepLinkRouter {
    var pending: AppRoute?

    func handle(url: URL) {
        guard url.scheme == "finalthird" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch (url.host, parts.first, parts.dropFirst().first) {
        case ("room", let id?, _):
            if let uuid = UUID(uuidString: id) { pending = .room(uuid) }
        case ("cigar", let id?, _):
            if let uuid = UUID(uuidString: id) { pending = .cigar(uuid) }
        case ("drop", let id?, _):
            if let uuid = UUID(uuidString: id) { pending = .drop(uuid) }
        case ("usual", _, _):
            pending = .theUsual
        default:
            pending = .home
        }
    }

    func consume() -> AppRoute? {
        defer { pending = nil }
        return pending
    }
}
