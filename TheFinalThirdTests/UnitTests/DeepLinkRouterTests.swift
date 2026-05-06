import Foundation
import Testing
@testable import TheFinalThird

@Suite("DeepLinkRouter")
@MainActor
struct DeepLinkRouterTests {
    @Test("Parses room URL into AppRoute.room")
    func parsesRoom() {
        let id = UUID()
        let router = DeepLinkRouter()
        guard let url = URL(string: "finalthird://room/\(id.uuidString)") else {
            Issue.record("URL malformed"); return
        }
        router.handle(url: url)
        #expect(router.consume() == .room(id))
    }

    @Test("Parses cigar URL")
    func parsesCigar() {
        let id = UUID()
        let router = DeepLinkRouter()
        guard let url = URL(string: "finalthird://cigar/\(id.uuidString)") else {
            Issue.record("URL malformed"); return
        }
        router.handle(url: url)
        #expect(router.consume() == .cigar(id))
    }

    @Test("Usual URL produces .theUsual")
    func parsesUsual() {
        let router = DeepLinkRouter()
        guard let url = URL(string: "finalthird://usual") else {
            Issue.record("URL malformed"); return
        }
        router.handle(url: url)
        #expect(router.consume() == .theUsual)
    }

    @Test("Wrong scheme is ignored")
    func ignoresWrongScheme() {
        let router = DeepLinkRouter()
        guard let url = URL(string: "https://thefinalthird.app/room/abc") else {
            Issue.record("URL malformed"); return
        }
        router.handle(url: url)
        #expect(router.consume() == nil)
    }

    @Test("consume() clears the pending route")
    func consumeClears() {
        let router = DeepLinkRouter()
        guard let url = URL(string: "finalthird://usual") else { return }
        router.handle(url: url)
        _ = router.consume()
        #expect(router.consume() == nil)
    }
}
