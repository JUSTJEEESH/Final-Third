import Foundation

extension DTO.Profile {
    func toDomain() -> Profile {
        var prefs = NotificationPrefs.default
        if let p = notif_prefs {
            prefs = NotificationPrefs(
                theUsual: p.the_usual ?? true,
                arrivalSignal: p.arrival_signal ?? true,
                drops: p.drops ?? true,
                events: p.events ?? true
            )
        }
        return Profile(
            id: id,
            email: email,
            displayName: display_name,
            handle: handle,
            avatarURL: avatar_url.flatMap(URL.init(string:)),
            bio: bio,
            country: country,
            city: city,
            isLocal: is_local,
            isPremium: is_premium,
            audioTheme: audio_theme.flatMap(AudioTheme.init(rawValue:)),
            voiceEnabled: voice_enabled,
            ghostModeDefault: ghost_mode_default,
            notificationPrefs: prefs,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            timezone: timezone,
            createdAt: created_at
        )
    }
}

extension DTO.Cigar {
    func toDomain() -> Cigar {
        Cigar(
            id: id,
            brand: brand,
            line: line,
            vitola: vitola,
            country: country,
            wrapper: wrapper,
            binder: binder,
            filler: filler,
            ringGauge: ring_gauge,
            length: length,
            strength: strength,
            flavorNotes: flavor_notes ?? [],
            originStory: origin_story,
            affiliateLink: affiliate_link.flatMap(URL.init(string:)),
            imageURL: image_url.flatMap(URL.init(string:)),
            funFact: fun_fact
        )
    }
}

extension DTO.Drink {
    func toDomain() -> Drink {
        Drink(
            id: id,
            brand: brand,
            name: name,
            category: category,
            subtype: subtype,
            imageURL: image_url.flatMap(URL.init(string:))
        )
    }
}

extension DTO.Room {
    func toDomain() -> Room {
        Room(
            id: id,
            ownerID: owner_id,
            name: name,
            description: description,
            theme: theme,
            isPrivate: is_private,
            audioTheme: audio_theme.flatMap(AudioTheme.init(rawValue:)),
            createdAt: created_at
        )
    }
}

extension DTO.Message {
    func toDomain() -> Message {
        Message(
            id: id,
            roomID: room_id,
            senderID: sender_id,
            body: body,
            editedAt: edited_at,
            deletedAt: deleted_at,
            createdAt: created_at,
            pendingState: .synced
        )
    }
}

extension DTO.Session {
    func toDomain() -> Session {
        Session(
            id: id,
            userID: user_id,
            roomID: room_id,
            cigarID: cigar_id,
            drinkID: drink_id,
            startedAt: started_at,
            endedAt: ended_at,
            durationMinutes: duration_minutes,
            flavorRating: flavor_rating,
            drawRating: draw_rating,
            overallRating: overall_rating,
            wouldSmokeAgain: would_smoke_again,
            notes: notes,
            moodScore: mood_score,
            unwindSuccess: unwind_success,
            lightingMethod: lighting_method.flatMap(Session.LightingMethod.init(rawValue:)),
            isGhost: is_ghost
        )
    }
}

extension DTO.Usual {
    func toDomain() -> Usual {
        Usual(
            id: id,
            userID: user_id,
            preferredTime: preferred_time.flatMap(Self.parseTime),
            cigarID: cigar_id,
            drinkID: drink_id,
            enabled: enabled,
            streakCount: streak_count,
            lastCompletedAt: last_completed_at
        )
    }

    private static func parseTime(_ raw: String) -> TimeOfDay? {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return TimeOfDay(hour: parts[0], minute: parts[1])
    }
}

extension DTO.Connection {
    func toDomain() -> Connection {
        Connection(
            id: id,
            requesterID: requester_id,
            addresseeID: addressee_id,
            status: Connection.Status(rawValue: status) ?? .pending,
            createdAt: created_at
        )
    }
}

extension DTO.Event {
    func toDomain() -> LoungeEvent {
        LoungeEvent(
            id: id,
            creatorID: creator_id,
            title: title,
            locationName: location_name,
            city: city,
            datetime: datetime,
            cigarID: cigar_id
        )
    }
}

extension DTO.Drop {
    func toDomain() -> CigarDrop {
        CigarDrop(
            id: id,
            cigarID: cigar_id,
            roomID: room_id,
            heroCopy: hero_copy,
            startsAt: starts_at,
            endsAt: ends_at
        )
    }
}

/// Shared decoder that matches Supabase JSON output. Postgres timestamptz
/// columns serialize as ISO-8601 strings with up to 6 digits of fractional
/// seconds and an explicit `+00:00` offset. The default
/// `JSONDecoder.dateDecodingStrategy = .iso8601` rejects fractional seconds
/// entirely, so we install a custom strategy that tolerates microseconds,
/// milliseconds, no fractional component, and trailing `Z` for UTC.
extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = JSONDecoder.parseSupabaseDate(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unparseable date: \(raw)"
            )
        }
        return d
    }()

    /// Tries fractional-second-aware ISO 8601 first (truncating microseconds
    /// to the 3 digits that ISO8601DateFormatter actually supports), then
    /// falls back to plain ISO 8601 without fractional seconds.
    static func parseSupabaseDate(_ raw: String) -> Date? {
        let trimmed = raw.replacingOccurrences(
            of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression
        )

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: trimmed) { return d }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: trimmed)
    }
}

extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
