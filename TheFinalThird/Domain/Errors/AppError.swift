import Foundation

enum AppError: Error, Sendable, Equatable, LocalizedError {
    case notAuthenticated
    case forbidden
    case offline
    case timeout
    case notFound(entity: String)
    case validation(String)
    case server(code: Int, message: String)
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "You need to sign in."
        case .forbidden:           return "You don't have access to that."
        case .offline:             return "You're offline. We'll catch up when you're back."
        case .timeout:             return "The connection timed out."
        case .notFound(let e):     return "We couldn't find that \(e.lowercased())."
        case .validation(let m):   return m
        case .server(_, let m):    return m
        case .decoding(let m):     return "Something didn't parse correctly: \(m)"
        case .unknown(let m):      return m
        }
    }
}
