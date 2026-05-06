import Foundation
import Testing
@testable import TheFinalThird

@Suite("DTO → domain mapping")
struct DTOMapperTests {
    @Test("Profile DTO maps notif_prefs and audio_theme")
    func profileMapping() {
        let id = UUID()
        let dto = DTO.Profile(
            id: id, email: "a@b.co", display_name: "Marcus", handle: "m",
            avatar_url: "https://example.com/a.png", bio: nil, city: "Tegucigalpa",
            is_honduras_local: true, is_premium: false,
            audio_theme: "rain",
            voice_enabled: true, ghost_mode_default: true,
            notif_prefs: .init(the_usual: false, arrival_signal: true, drops: nil, events: nil),
            timezone: "America/Tegucigalpa",
            created_at: Date(timeIntervalSince1970: 0)
        )
        let p = dto.toDomain()
        #expect(p.id == id)
        #expect(p.displayName == "Marcus")
        #expect(p.audioTheme == .rain)
        #expect(p.notificationPrefs.theUsual == false)
        #expect(p.notificationPrefs.arrivalSignal == true)
        #expect(p.notificationPrefs.drops == true)   // nil falls back to default true
        #expect(p.isHondurasLocal == true)
        #expect(p.ghostModeDefault == true)
        #expect(p.timezone == "America/Tegucigalpa")
    }

    @Test("Cigar DTO defaults flavor_notes to empty array")
    func cigarMapping() {
        let dto = DTO.Cigar(
            id: UUID(), brand: "Padron", line: "1964 Anniversary",
            vitola: "Diplomatico", country: "Nicaragua", wrapper: "Maduro",
            binder: nil, filler: nil, ring_gauge: 50, length: 7.0, strength: 4,
            flavor_notes: nil, origin_story: nil, affiliate_link: nil,
            image_url: nil, fun_fact: nil
        )
        let c = dto.toDomain()
        #expect(c.flavorNotes.isEmpty)
        #expect(c.displayName == "Padron 1964 Anniversary")
        #expect(c.strength == 4)
        #expect(Cigar.Strength(rawValue: 4)?.label == "Medium–Full")
    }

    @Test("Usual time string parses HH:MM")
    func usualMapping() {
        let dto = DTO.Usual(
            id: UUID(), user_id: UUID(),
            preferred_time: "21:30",
            cigar_id: nil, drink_id: nil,
            enabled: true, streak_count: 5,
            last_completed_at: nil
        )
        let u = dto.toDomain()
        #expect(u.preferredTime?.hour == 21)
        #expect(u.preferredTime?.minute == 30)
        #expect(u.streakCount == 5)
    }

    @Test("Message DTO marks pendingState as synced")
    func messageMapping() {
        let dto = DTO.Message(
            id: UUID(), room_id: UUID(), sender_id: UUID(),
            body: "hi", edited_at: nil, deleted_at: nil,
            created_at: Date(timeIntervalSince1970: 0)
        )
        let m = dto.toDomain()
        #expect(m.pendingState == .synced)
    }

    @Test("Connection DTO falls back to .pending on bad status")
    func connectionMapping() {
        let dto = DTO.Connection(
            id: UUID(), requester_id: UUID(), addressee_id: UUID(),
            status: "garbage", created_at: Date(timeIntervalSince1970: 0)
        )
        #expect(dto.toDomain().status == .pending)
    }
}
