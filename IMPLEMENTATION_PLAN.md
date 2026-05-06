# The Final Third — Implementation Plan (v1)

Scope: complete production iOS app per PRD v3, schema spec, and engineering rules.

---

## 1. Architecture Overview

**Pattern:** SwiftUI + MVVM with `@Observable` (Swift 6, iOS 17+). Strict separation:

```
View  ──▶  ViewModel (@Observable)  ──▶  Repository (protocol)  ──▶  DataSource(s)
                                            │                         ├─ SupabaseClient (remote)
                                            │                         ├─ CoreData (local cache)
                                            │                         └─ Realtime channels / WebRTC
                                            └── domain models (structs, Sendable)
```

**Layers**

1. **App Shell** — entry, root tab coordinator, theme, deep links, scene phase.
2. **Design System** — tokens (colors, type, spacing, motion), reusable atoms/molecules, haptics, audio mixer.
3. **Core Services** (singletons via dependency container)
   - `AuthService` (Sign in with Apple + email)
   - `SupabaseClient` wrapper
   - `RealtimeService` (channel manager with reconnect + dedupe)
   - `VoiceService` (LiveKit wrapper, push-to-talk)
   - `AudioEngine` (ambient mix bus + ducking for voice)
   - `OfflineQueue` (CoreData-backed write queue)
   - `ConfigService` (`app_config` cache + TTL)
   - `NotificationService` (APNs + local for The Usual)
   - `EntitlementService` (RevenueCat → mirrors `is_premium`)
   - `HapticsService` (CoreHaptics patterns)
   - `AnalyticsService` (event protocol; no PII)
4. **Repositories** (protocol + impl per domain)
   - Profile, Cigar, Drink, Room, Message, Session, Usual, Connection, Event, Drop, Reputation, Presence.
5. **Features** (folder per feature, each contains View / ViewModel / Components / local types)
   - Auth, Onboarding, Home, Explore, Lounge, Room, LightingCeremony, Session, Journal, Profile, Social, Events, Drops, Paywall, Settings.

**Concurrency:** `actor` for any service touching shared mutable state (queues, channel registries). All repos `async`/`await`. Views never call DataSources directly.

**Dependency Injection:** lightweight container (`AppContainer`) injected into root via `.environment(\.container)`; ViewModels read what they need in `init`. No singletons inside features.

---

## 2. Schema Validation & Gaps

PRD requirements vs `SUPABASE_SCHEMA.sql` — the schema is a strong skeleton but needs additions before build:

### Missing tables / columns
| Need (from PRD) | Gap | Fix |
|---|---|---|
| Avatar rail / live presence | No `room_presence` row state | Add `room_presence(room_id, user_id, joined_at, is_ghost, last_seen)` (REPLICA IDENTITY FULL for realtime). |
| Voice rooms (4–6 speakers) | None | `voice_rooms(id, room_id, max_speakers)` + `voice_participants(voice_room_id, user_id, role, muted)`. |
| Ghost mode session | None | Add `is_ghost boolean` to `sessions` and `room_presence`. |
| Lighting method on session | None | Add `lighting_method text` (match/torch/cedar) to `sessions`. |
| Ambient audio preference | None | Add `audio_theme text`, `voice_enabled boolean`, `ghost_mode_default boolean`, `notif_prefs jsonb` to `profiles`. |
| Cigar Drops (weekly featured + limited rooms) | Modeled only as `app_config` keys | Add `drops(id, cigar_id, room_id, starts_at, ends_at, hero_copy)`. |
| Reputation badges | None | `badges(id, code, name, description)` + `user_badges(user_id, badge_id, earned_at)`. |
| Connection chemistry | Not stored | Materialized view `connection_chemistry` over sessions. |
| Event RSVPs | None | `event_rsvps(event_id, user_id, status)`. |
| Push notifications | None | `device_tokens(user_id, token, platform, env)`. |
| Premium / RevenueCat sync | Boolean only | `entitlements(user_id, product_id, active, renews_at, store)`. |
| Cigars community add | `cigars_pending` exists ✓ | Add `status` + reviewer fields. |
| Message edits/deletes | None | Add `edited_at`, `deleted_at` to `messages`. |
| Reactions canonicalization | Free-text | Constrain to small enum or lookup. |
| Burn timer / thirds | Derived only | OK — compute client-side from `started_at`; keep DB lean. |

### Index / RLS gaps
- `room_members`: needs `unique(room_id, user_id)`.
- `connections`: needs `unique(least(requester,addressee), greatest(...))` or check.
- RLS: write explicit policies for **chat insert requires room membership**, **only owner edits session**, **profile self-update**, **private room visibility**, **drops public read**, **app_config public read**, **service role only writes**.
- Realtime: enable replication on `messages`, `room_presence`, `room_members`, `voice_participants`.

### Conflicts to resolve
- PRD says realtime presence via Supabase **and** session presence — clarify: Supabase Presence channel for ephemeral "in room now"; `room_presence` table only for ghost-toggle persistence and Arrival Signal triggering.
- PRD says "UITableView wrapper for messages" but Swift 6 SwiftUI `List` with `.id`/`scrollPosition` is now performant — recommend `List` with `LazyVStack` fallback; only drop to UIKit if profiling shows need. Document the decision in BUILD_LOG.
- "is_premium boolean" vs RevenueCat — keep boolean as cached read, source of truth = RevenueCat; sync via webhook → edge function → `entitlements` row.

---

## 3. Folder / File Structure

```
TheFinalThird/
├── App/
│   ├── TheFinalThirdApp.swift
│   ├── RootView.swift
│   ├── AppContainer.swift
│   ├── DeepLinkRouter.swift
│   └── SceneLifecycle.swift
├── DesignSystem/
│   ├── Tokens/ (Colors, Typography, Spacing, Motion, Gold)
│   ├── Components/ (FTButton, FTCard, AvatarView, GoldDivider, EmberBadge, …)
│   ├── Haptics/HapticsService.swift
│   └── Theme.swift
├── Core/
│   ├── Auth/AuthService.swift
│   ├── Supabase/SupabaseClient+Config.swift
│   ├── Realtime/
│   │   ├── RealtimeService.swift
│   │   ├── ChannelRegistry.swift
│   │   └── PresenceTracker.swift
│   ├── Voice/
│   │   ├── VoiceService.swift  (LiveKit)
│   │   └── PushToTalkController.swift
│   ├── Audio/
│   │   ├── AudioEngine.swift
│   │   ├── AmbientMixer.swift
│   │   └── Assets/  (jazz, lofi, rain, fireplace, murmur — looped, AAC)
│   ├── Offline/
│   │   ├── CoreDataStack.swift
│   │   ├── OfflineQueue.swift
│   │   └── Models.xcdatamodeld
│   ├── Config/ConfigService.swift
│   ├── Notifications/NotificationService.swift
│   ├── Entitlements/EntitlementService.swift  (RevenueCat)
│   └── Analytics/AnalyticsService.swift
├── Domain/
│   ├── Models/  (Profile, Cigar, Drink, Room, Message, Session, Usual, Connection, Event, Drop, Badge — Sendable structs)
│   └── Errors/AppError.swift
├── Data/
│   ├── Repositories/  (ProfileRepository.swift + Impl, … one file per domain)
│   ├── DTO/  (Codable Supabase rows)
│   └── Mapping/  (DTO → Domain)
├── Features/
│   ├── Auth/  (SignInView, OnboardingView, ProfileSetupView, AuthViewModel)
│   ├── Home/
│   ├── Explore/
│   ├── Lounge/  (room list + room detail entry)
│   ├── Room/   (active room: chat, presence, voice, ambient, burn timer)
│   ├── LightingCeremony/  (LightingView, FlameCanvas, EmberParticles, …)
│   ├── Session/  (BurnTimer, FinalThirdMoment, SessionSummary)
│   ├── Journal/
│   ├── Profile/
│   ├── Social/  (Connections, Chemistry)
│   ├── Events/
│   ├── Drops/
│   ├── Paywall/
│   └── Settings/
├── Resources/  (Assets.xcassets, Sounds, Lottie, Localizations)
├── Tests/
│   ├── UnitTests/  (Auth, Repos, Sessions, Realtime, OfflineQueue)
│   ├── SnapshotTests/  (DesignSystem, LightingCeremony key frames)
│   └── UITests/  (golden flows)
└── supabase/
    ├── migrations/  (numbered SQL)
    ├── policies/    (RLS)
    └── functions/   (edge: revenuecat-webhook, weekly-recap, streak-cron, notif-scheduler, ai-sommelier)
```

---

## 4. Dependency Setup (SPM)

- `supabase-swift` (auth, db, realtime, storage)
- `livekit-client-swift` (voice rooms + PTT)
- `RevenueCat`
- `Lottie` (only for non-critical UI flourishes; lighting ceremony is custom Canvas)
- `swift-collections` (OrderedDictionary for chat dedupe)
- `Sentry` (or OSLog-only if avoiding 3p) — decide before ship.

iOS frameworks: SwiftUI, Combine (minimal), CoreData, AVFAudio, AVFoundation, CoreHaptics, UserNotifications, AuthenticationServices, Network (reachability), BackgroundTasks (streak refresh).

Tooling: SwiftLint + SwiftFormat, swift-testing for unit, XCTest for UI, snapshot via `swift-snapshot-testing`. CI: GitHub Actions matrix on Xcode 16, run unit + snapshot on PR.

---

## 5. Build Order (mapped to PRD §BUILD ORDER, expanded)

1. **Project + tooling** — Xcode project, SPM, lint, CI, design tokens, dark theme, sample screen.
2. **Supabase migrations + RLS** — apply schema additions (§2), seed cigars/drinks, app_config, drops table, badges seed.
3. **Auth + Onboarding** — Sign in with Apple, email fallback, profile setup, Honduras toggle, session persistence via Keychain.
4. **Core services scaffolding** — Container, ConfigService, RealtimeService skeleton, OfflineQueue, NotificationService permissions.
5. **Data layer** — Cigar/Drink/Profile repos with CoreData mirror, search-local-first, image caching.
6. **Explore tab** — search + filters (region, strength, wrapper), Cigar Detail, Drink Detail.
7. **Lounge base** — Room list, Room create/join, presence rail, **chat (text only)** with pagination + dedupe + reconnect.
8. **Session system** — start/stop, burn timer (thirds), final-third gold pulse + haptic + banner, summary capture (ratings, mood, unwind).
9. **Lighting Ceremony** — full-screen flow + flame animation + haptics + audio cue + cigar reveal (see §10).
10. **Journal** — history list, stats dashboard, weekly recap, premium gate at 30 sessions.
11. **Home tab** — greeting (time-aware), Tonight's Pick, Active Rooms, Your Ritual, Drop of the Week, Nearby Tonight.
12. **Profile + Social** — profile, connections (add/accept/decline), Chemistry view, badges.
13. **Events** — list, create, RSVP, "Who's smoking in [city]".
14. **Drops** — Drop of the Week surface, limited-time rooms.
15. **Paywall** — RevenueCat integration, gates wired (private rooms, journal >30, pairings, advanced Usual).
16. **Audio + Voice** — ambient mixer per room, voice rooms (LiveKit), push-to-talk, ducking, ghost mode integration, Arrival Signal.
17. **Final polish** — empty-state copy pass, motion polish, accessibility audit, performance pass on long chats, loading skeletons, error states, App Store assets.

Each step ends with: tests added, BUILD_LOG entry, manual smoke test on device.

---

## 6. Realtime Architecture

**Channels** (Supabase Realtime):
- `room:{room_id}:chat` — postgres_changes on `messages`.
- `room:{room_id}:presence` — Supabase Presence (ephemeral, source of truth for "in room now").
- `room:{room_id}:reactions` — postgres_changes on `message_reactions`.
- `user:{user_id}:notifs` — server broadcast for arrival signal, drops.

**ChannelRegistry (actor):**
- One channel per room subscribed only when `RoomView` is on screen.
- Reference-counted; closed on last consumer.
- Backoff reconnect (1s → 2s → 4s → 8s → 30s cap) using Network framework reachability.
- **Dedupe**: each inbound message keyed by `id`; `OrderedSet` of recent ids (last 500) per room.
- **Catch-up**: on reconnect, fetch `messages where created_at > lastSeen` then merge.
- **Outbox**: messages enqueued offline; on send, optimistic insert with `pending` flag, replaced when DB ack arrives; idempotency via client-side `id` (UUID v7).

**Presence:**
- Track `{user_id, display_name, avatar_url, is_ghost}`.
- Ghost users excluded from broadcast list.
- Arrival Signal: when a *connection* (friend) enters non-ghost → local notification + haptic + banner.

**Voice (LiveKit):**
- Separate room namespace `voice:{room_id}`.
- Speaker cap enforced server-side via `voice_rooms.max_speakers` + token signing in edge function.
- PTT: hold-to-talk; when released, mute. Live mode: always on, mute toggle.
- AudioSession category `.playAndRecord` with `.duckOthers, .allowBluetooth, .mixWithOthers` carefully managed; ambient ducks under voice.

---

## 7. Offline Sync Architecture

**CoreData entities (mirror, not source of truth):**
- `CDCigar`, `CDDrink`, `CDSession`, `CDUsual`, `CDProfile`, `CDPendingWrite`.

**Reads:** repositories return local first, then async refresh from Supabase (`stale-while-revalidate`). TTL per entity (cigars: 24h; drinks: 24h; profile: 1h; app_config: 15m).

**Writes:** every mutation goes through `OfflineQueue.enqueue(op)` where `op` is a `Codable` envelope `(id, kind, payload, createdAt, attempts)`. Queue runs when reachable; ordered, idempotent (server checks `id`). Failed ops backoff; surfaced in Settings → "Pending Sync (n)".

**Conflict resolution:** last-write-wins for user-owned rows; server timestamps authoritative. Sessions never edited after end (immutable).

**What works offline:** browse cached cigars/drinks, view journal, start a session (queued), write notes, set The Usual. **Does not work:** lounge chat, voice, presence, drops.

---

## 8. Voice Integration Approach

- **SDK:** LiveKit (mature Swift SDK, SwiftUI sample, scales to thousands of rooms; alternative Agora considered but heavier API).
- **Token issuance:** Supabase edge function `livekit-token` validates membership + entitlement, signs JWT with room-scoped grants (canPublish based on speaker slot availability).
- **Topology:** SFU (LiveKit Cloud or self-hosted). Max 6 publishers, unlimited subscribers.
- **PTT UX:** large gold capsule button at bottom of RoomView; press-and-hold; visual ring while transmitting; haptic on release.
- **Ambient ducking:** `AudioEngine` listens to LiveKit "active speaker" events and ramps ambient gain −12 dB over 250 ms.
- **Privacy:** voice opt-in per session; mic permission gated behind explicit prompt copy; ghost mode forces mute.
- **Network:** Opus 32 kbps default; downgrade to 16 kbps on poor links via LiveKit adaptive.

---

## 9. Lighting Ceremony — Animation Strategy

Goal: emotional anchor, ~6 seconds, feels physical, never skippable on first-of-day session.

**Tech stack (in order of fallback):**
1. **`TimelineView` + `Canvas` + Metal shader** (`MetalView` wrapped) for the flame core — procedural noise-based fluid; high frame rate; respects ProMotion.
2. **`CAEmitterLayer`** (UIViewRepresentable) for sparks + ember particles — battle-tested, low cost.
3. **`PhaseAnimator` / `KeyframeAnimator`** (iOS 17) for screen dim, cigar reveal, name fade-in.
4. **CoreHaptics** custom pattern: ignition tick → low rumble → settle pulse, synced to flame intensity curve.
5. **AVAudioEngine** layered loop: match strike SFX → flame whoosh → low ember bed → fade.
6. **Lottie** is **not** used for the flame (looks fake); only for tiny accent moments if any.

**Choreography (frames, 60 fps target):**
- 0.0 s: screen dims to 4 % luminance, vignette in.
- 0.4 s: lighting method asset (match/torch/cedar) animates in from below; haptic tick.
- 0.9 s: flame ignites (Metal noise field, gold→amber gradient); whoosh SFX; rumble haptic.
- 1.6 s: cigar foot glows (radial gradient + bloom); ember particles; cinematic letterbox.
- 3.0 s: cigar name fades in (Display serif, gold); subtitle (vitola) fades in.
- 5.5 s: settle pulse haptic; tap-to-enter prompt appears.
- Exit: crossfade into RoomView; ambient audio crossfades up.

**Accessibility:** Reduce Motion → static cinemagraph + haptic + name reveal (no particle/Metal). VoiceOver: announces "Lighting your [cigar]." Reduce Transparency dims vignette only.

**Performance budget:** keep flame view ≤ 6 ms/frame on iPhone 13; gate Metal path on `MTLDevice.supportsFamily(.apple7)`, fall back to Canvas.

---

## 10. Animation / Motion System (general)

- Centralized `Motion` tokens (durations: quick 180 ms, smooth 320 ms, breathe 800 ms; curves: `.easeOut(0.22, 1, 0.36, 1)` etc.).
- Final-third gold pulse: `PhaseAnimator` 3-phase loop (rest → bloom → rest), 1.6 s cycle, ramps audio low-pass.
- Arrival Signal: spring-in banner + 1× soft haptic; never stacks (debounced 8 s per user).
- Ember-to-Fire streak: stateful symbol that morphs across thresholds (1, 7, 30).

---

## 11. Testing Strategy

Per Engineering Rules + expansion:

| Layer | Framework | Coverage target |
|---|---|---|
| Domain models / mappers | swift-testing | 90 % |
| Repositories (mock SupabaseClient + CoreData in-memory) | swift-testing | 85 % |
| AuthService | swift-testing | full SIWA happy + revoke |
| RealtimeService | swift-testing + harness mocking websocket | reconnect, dedupe, catch-up |
| OfflineQueue | swift-testing | enqueue/dequeue/replay/idempotency |
| Lighting Ceremony | snapshot @ key frames + manual perf | golden frames |
| Lounge flow | UITest on simulator + device | Step 0–3 + final third |
| Paywall gating | UITest | premium on/off branches |

CI gates: lint, build, unit, snapshot. UI tests nightly. Manual perf checklist before each TestFlight: chat with 1 000 messages, 6-speaker voice, 30 m session, low-power mode.

---

## 12. Risks

1. **Lighting ceremony perf** — Metal flame on older devices. Mitigation: Canvas fallback + reduce-motion path.
2. **Audio session conflicts** — ambient + voice + system audio. Mitigation: single `AudioEngine` owner, strict category transitions, real-device tests.
3. **Realtime cost / scale** — 100 k users with persistent presence. Mitigation: presence channels only when room visible; idle disconnect after 60 s background.
4. **Voice abuse** — PTT moderation. Mitigation: report + mute, server-side recording flag (off by default), rate-limited speaker grants.
5. **RevenueCat ↔ `is_premium` drift** — webhook latency. Mitigation: client trusts RevenueCat in-process; DB boolean is cache; gate UI on RC.
6. **CoreData migrations** — schema evolves rapidly early. Mitigation: lightweight migrations only; reset cache on auth change.
7. **Sign in with Apple email relay** — handle `null` email + private relay. Mitigation: persist Apple credential ID; never key user on email.
8. **Notifications fatigue** — The Usual + Arrival Signal can stack. Mitigation: per-category prefs, quiet hours, dedupe.
9. **Voice + ambient ducking on AirPods** — known route-change issues. Mitigation: observe `AVAudioSession.routeChangeNotification`, re-establish session.
10. **Honduras local toggle** — abuse / verification. Mitigation: self-declared only at v1, server-side flag for later moderation.

---

## 13. Edge Cases (catalog)

- Cold start with no network → cached Home; clear "Offline" pill; queue any session start.
- Mid-session network loss → burn timer continues locally; chat shows "reconnecting"; voice reconnects or drops gracefully.
- Backgrounded during ceremony → pause animation, resume from same phase on foreground.
- User toggles ghost mid-session → presence row updates; arrival signals suppressed retroactively (no replay).
- User in two rooms? → disallow; switching rooms ends current session optionally or keeps timer running but leaves chat.
- Subscription expires mid-session → grandfather current session, gate next entry.
- Apple ID revoked → server-side detect, sign out, retain journal locally for export.
- Streak edge: timezone change, DST, clock skew → compute streak on server using user's stored TZ.
- Empty cigar library on first launch → seed bundle JSON imported into CoreData on install.
- Reactions on deleted message → soft-delete preserves row.
- Long chat scroll → keep last 100 in memory, page older; release on view disappear.
- Voice room full when joining → fall back to listener; queue speaker slot.
- VoiceOver during ceremony → skip option always reachable.
- Family-shared subscription → RevenueCat handles; verify with sandbox.

---

## 14. Suggested Improvements (beyond PRD)

- **Idempotency keys (UUID v7) on every write** — simplifies offline replay.
- **`StreakLedger` table** instead of mutable counter — auditable, fixes timezone bugs.
- **Server-driven copy** via `app_config` for greeting variants, drop hero text — ship copy without releases.
- **"Quiet Hours"** in NotificationService — never ping during user's stored sleep window.
- **Cigar of-the-night auto-suggest** in The Usual — based on weather + last 7 sessions; cheap heuristic before AI Sommelier edge function.
- **Visible reconnect status** in chat header — small "reconnecting…" pill; honesty > silence.
- **Privacy-by-default voice** — opt-in per room, mic indicator always visible.
- **Local-only "Notes"** drafts in Journal — encrypts with device key; opt-in cloud sync.
- **Crash-safe ceremony** — store "last ceremony seen" so we never replay if the app crashed mid-flame.
- **Snapshot tests for Gold tokens** — prevents the most likely visual regression.
- **Telemetry guardrails** — analytics events typed via enum; no free-text properties.

---

## 15. Module Breakdown (one-line summaries)

- `App` — composition root, theme, deep links.
- `DesignSystem` — visual contract; everything else consumes it.
- `Core/Auth` — SIWA + email + session.
- `Core/Supabase` — typed client wrapper.
- `Core/Realtime` — actor-based channel manager.
- `Core/Voice` — LiveKit + PTT.
- `Core/Audio` — ambient mixer + ducking.
- `Core/Offline` — CoreData + queue.
- `Core/Config` — `app_config` cache.
- `Core/Notifications` — APNs + local + categories.
- `Core/Entitlements` — RevenueCat bridge.
- `Domain` — pure structs, errors.
- `Data/Repositories` — CRUD + cache strategy.
- `Features/*` — UI per PRD section, no business logic.
- `supabase/` — migrations, policies, edge functions.

---

## 16. Definition of Done (per feature)

- ✅ Repository unit-tested
- ✅ ViewModel unit-tested (no view dependencies)
- ✅ Empty / error / loading states designed and implemented
- ✅ Dark-mode tokens only
- ✅ VoiceOver labels + Dynamic Type pass
- ✅ Reduce Motion path
- ✅ Realtime + Offline behaviors verified
- ✅ Snapshot or UI test on golden flow
- ✅ BUILD_LOG entry with decisions

---

**END OF PLAN — awaiting approval before implementation.**
