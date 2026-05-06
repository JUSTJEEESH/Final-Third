# BUILD LOG — The Final Third

Use this to:

* Track progress
* Paste Claude outputs
* Keep decisions consistent

---

## 2026-05-06 — Milestone 0: Plan approved

- Plan written to `IMPLEMENTATION_PLAN.md` and approved.
- Branch: `claude/execute-plan-prompt-NsSEE`.

---

## 2026-05-06 — Milestone 1: Project skeleton + tooling

**What landed**

- Folder skeleton: `TheFinalThird/{App,DesignSystem,Core,Domain,Data,Features,Resources}`, `TheFinalThirdTests/{UnitTests,SnapshotTests,UITests}`, `supabase/{migrations,policies,functions,seed}`.
- `.gitignore`, `.swiftlint.yml`, `.swiftformat`, `.swift-version`, `Mintfile`, `.env.example`.
- `project.yml` (XcodeGen) — single-target iOS app, Swift 6, complete strict concurrency, iOS 17 deployment, dark-only UI, background modes (audio/voip/fetch/remote-notification), packages: Supabase, RevenueCat, LiveKit, Lottie, swift-collections, swift-snapshot-testing.
- `Config/Base.xcconfig` + `Config/Secrets.xcconfig.example` for secrets injection (Engineering Rules: anon key only on-device).
- `TheFinalThird/App/Info.plist` references xcconfig variables (no secrets in repo).

**Decisions**

- Use **XcodeGen** rather than a checked-in `.xcodeproj` to keep diffs reviewable and stop merge churn. Generate locally with `mint run xcodegen` (Mintfile pins versions).
- Single-target app — module split via folder boundaries, not separate frameworks. Re-evaluate if compile times exceed ~30 s.
- Strict concurrency = `complete` from day 1 — Swift 6 only per Engineering Rules.

---

## 2026-05-06 — Milestone 2: Supabase migrations + RLS + seed

**What landed**

- `supabase/migrations/0001_init_schema.sql` — extended schema beyond original spec:
  - **Added tables:** `room_presence`, `voice_rooms`, `voice_participants`, `event_rsvps`, `drops`, `badges`, `user_badges`, `entitlements`, `device_tokens`.
  - **Added columns:** profiles got `audio_theme`, `voice_enabled`, `ghost_mode_default`, `notif_prefs`, `quiet_hours_start/end`, `timezone`, `updated_at`. sessions got `lighting_method`, `is_ghost`. messages got `edited_at`, `deleted_at`.
  - **Hardening:** `unique(room_id, user_id)` on `room_members`; pair-uniqueness on `connections` via expression index; `cigars_pending.status` enum; canonical `message_reactions.reaction` enum (`toast/fire/smoke/salute/love`); `length(body) between 1 and 2000` check on messages; `mood_score 1..10`; `lighting_method` enum.
  - **Triggers:** `set_updated_at` on profiles/usuals/connections/entitlements/device_tokens/app_config.
  - **Realtime publication:** added messages, message_reactions, room_presence, room_members, voice_participants. `replica identity full` set.
  - **Indexes:** brand+line, strength, wrapper on cigars; category on drinks; city+datetime on events; starts_at+ends_at on drops; existing user/room indexes preserved.
- `supabase/migrations/0002_rls_policies.sql` — RLS on every table:
  - Profiles: public read, self-update.
  - Cigars / drinks / drops / badges / app_config: public read.
  - Rooms: public visible to all; private only to owner + members.
  - Messages: read iff room visible (with deleted-at filter); insert requires membership.
  - Reactions: insert/delete self.
  - Voice participants: self-managed.
  - Sessions / usuals / entitlements / device_tokens: only owner.
  - Connections: visible to either party; insert as requester.
  - Events: anyone reads; creator-only writes; RSVPs self-managed.
- `supabase/migrations/0003_views_and_helpers.sql`:
  - View `connection_chemistry` aggregating pair sessions/minutes/last-session-at.
  - Streak trigger `update_streak_on_session_end` — increments if within 36 h of last completion, else resets to 1.
- `supabase/seed/badges.sql` — Good Company, Regular, Palate Pro, First Light, Ember/Flame/Fire.
- `supabase/seed/app_config.sql` — greetings (server-driven copy), lighting methods, audio themes, allowed reactions, paywall copy.

**Decisions**

- Realtime presence is split: ephemeral "in the room right now" comes from Supabase Presence channel; `room_presence` table backs ghost-mode persistence and arrival-signal triggers. Fewer DB writes, fast UI.
- Soft-delete on messages (`deleted_at`) instead of hard delete — preserves reaction history and audit trail.
- Streak logic in the DB (trigger) so timezone changes/clock skew can't corrupt the counter from a misbehaving client.
- `connection_chemistry` is a regular view (cheap query); promote to materialized view if profiling shows it's hot.
- Reactions are a closed enum, not free text — easier UI, cheaper storage, prevents Slack-style reaction sprawl.

---

## 2026-05-06 — Milestone 3: Design System

**What landed**

- `DesignSystem/Tokens/FTColor.swift` — semantic colors. **Gold is meaning, not decoration**: tokens for surface/ink/gold/ember/state/overlays. Hex helper extension on `Color`.
- `FTTypography.swift` — system fonts; serif for ritual moments (display), sans for body, monospaced for chat timestamps. Designed to swap in a licensed face later via `Resources`.
- `FTSpacing.swift` — `FTSpace` (xxs…xxxl), `FTRadius`, `FTStroke`.
- `FTMotion.swift` — durations (quick/smooth/slow/breathe/ritual) and curves (ease-out-soft, breathe loop, gold pulse). No bouncy springs.
- `Theme.swift` — `.ftTheme()` view modifier: dark scheme, gold tint, ink foreground, body font.
- `Components/`: `FTButton` (gold/ghost/ember/danger), `FTCard`, `GoldDivider`, `AvatarView` (with active ring + ghost dim), `EmberBadge` (Ember→Flame→Fire by streak).
- `Haptics/HapticsService.swift` — singleton with simple feedback (`tap/soft/success/warning`) plus ritual patterns: `playLightingPattern` (ignition tick + 1.4 s rumble + settle pulse), `playFinalThirdPattern` (3-pulse low-frequency), `playArrivalSignal` (single soft).

**Decisions**

- One source of color truth — every other file consumes `FTColor`, never `Color(...)` literals. Snapshot tests will guard the gold tokens since they're the most likely visual regression.
- `HapticsService` is `@MainActor` and stateless aside from the engine — avoids over-architecting; engine is auto-shutdown.
- Defer Lottie until a feature needs it — flame uses Canvas+Metal (next milestone), not Lottie.

---

## 2026-05-06 — Milestone 4: Domain models + errors

**What landed**

- `Domain/Models/`: `Profile` (+ `NotificationPrefs`, `TimeOfDay`, `AudioTheme` enum), `Cigar` (+ `Strength`), `Drink`, `Room` (+ `RoomMember`, `RoomPresence`), `Message` (+ `Reaction` enum, `PendingState`), `Session` (+ `LightingMethod`, `Third` w/ `currentThird()` helper for burn-timer math), `Usual`, `Connection` (+ `ConnectionChemistry`), `LoungeEvent` (+ `EventRSVP`), `CigarDrop` (with `isLive`), `Badge` (+ `UserBadge`).
- `Domain/Errors/AppError.swift` — typed app errors with localized descriptions.

**Decisions**

- All models are `Sendable` value types — Swift 6 strict concurrency requires this.
- Burn-timer thirds computed in `Session.currentThird(now:)` so the view layer is dumb.
- `Message.PendingState` is local-only (synced/pending/failed) — drives the optimistic UI for the offline outbox.

---

## 2026-05-06 — Milestone 5: Core services

**What landed**

- `Core/Supabase/SupabaseEnv.swift` — reads creds from `Info.plist` (xcconfig-injected). Hard-fails on missing keys.
- `Core/Supabase/SupabaseClient+Config.swift` — single shared `SupabaseClient.live` with PKCE auth and Keychain storage.
- `Core/Supabase/KeychainAuthStorage.swift` — `AuthLocalStorage` impl using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- `Core/Auth/AuthService.swift` — `@Observable`, owns `AuthState`, listens to `authStateChanges`, handles SIWA + email + sign out.
- `Core/Auth/AppleSignInCoordinator.swift` — full Sign in with Apple flow with nonce + SHA-256, returns identity token for Supabase exchange.
- `Core/Realtime/RealtimeService.swift` — actor managing per-room channels with reference counting, dedupe via `OrderedSet<UUID>` (last 500), postgres_changes for messages + reactions, presence join/leave events. **Note:** the exact `postgresChange` API call shape differs between Supabase Swift SDK versions; adjust to the chosen pin (project.yml uses 2.20+) before first integration test.
- `Core/Audio/AudioEngine.swift` — `AVAudioSession` + `AVAudioEngine` with looped buffer playback for ambient themes; supports duck/unduck ramps for voice cooperation.
- `Core/Voice/VoiceService.swift` — LiveKit `Room` wrapper. PTT via `setTransmitting(on:)`; tokens come from a Supabase edge function via injected `tokenProvider`.
- `Core/Offline/CoreDataStack.swift` — local cache stack with auto-migration + reset on incompatibility.
- `Core/Offline/OfflineQueue.swift` — actor that persists `Op` envelopes to Documents/, replays on `NWPathMonitor` recovery, exponential drop after 10 attempts. Each op has a UUID idempotency key.
- `Core/Config/ConfigService.swift` — fetches `app_config` rows; 15-min TTL; `AnyDecodable` for jsonb values; never crashes the app on failure.
- `Core/Notifications/NotificationService.swift` — auth + APNs registration + scheduled `UNCalendarNotificationTrigger` for The Usual ("Your chair is ready.").
- `Core/Entitlements/EntitlementService.swift` — RevenueCat configured with the user's UUID as `appUserID`; mirrors `isPremium` and `renewsAt`.
- `Core/Analytics/AnalyticsService.swift` — typed `Event` enum; OSLog backend; no free-text properties.

**Decisions**

- `RealtimeService` is an `actor` to keep channel state isolated; views consume via `AsyncStream`.
- `OfflineQueue` is a separate actor and persists to disk on every mutation (atomic write) — losing a queued session start because the app was killed would be a real failure.
- `ConfigService` keeps last known values forever on failure — atmosphere apps shouldn't show error states for copy.

---

## 2026-05-06 — Milestone 6: App entry, container, root, custom tab bar

**What landed**

- `App/AppContainer.swift` — `@Observable` DI container; exposes auth/config/entitlements/notifications/realtime/voice/audio/offlineQueue/analytics. Bootstraps in order: auth → notifications → config → RC.
- `App/DeepLinkRouter.swift` — parses `finalthird://room/<uuid>`, `cigar/<uuid>`, `drop/<uuid>`, `usual` into typed `AppRoute`.
- `App/TheFinalThirdApp.swift` — `@main`; injects container + router as environment; applies `.ftTheme()`; `task` bootstraps; `onOpenURL` routes deep links.
- `App/AppDelegate.swift` — minimal hook for APNs token (stored in `PendingPushToken` and consumed by `NotificationService` once available).
- `App/RootView.swift` — branches on `auth.state` between splash, an auth placeholder (Sign in with Apple wired), and the main tab bar.
- `App/MainTabView.swift` — custom dark tab bar with five tabs (Home/Explore/Lounge/Journal/Profile); placeholder content panes — feature folders fill these in subsequent milestones.

**Decisions**

- Auth UI is a placeholder for now (just SIWA button) — full Auth feature with email + onboarding lands in milestone 7.
- Custom tab bar instead of `TabView` — needed gold-aware styling and PRD mandates "custom tab bar, dark theme only, gold accent system".
- Container construction is light; expensive work (RC, network) happens in `bootstrap()` post-launch.

---

## 2026-05-06 — Milestone 7: Auth feature

**What landed**

- `Features/Auth/AuthViewModel.swift` — three-step state machine (`landing → email → profileSetup`) with email validation and password length guards. Backed by `AuthService` + `ProfileRepository`.
- `Features/Auth/AuthView.swift` — Landing (SIWA + email entry), Email (sign in / sign up toggle), Profile Setup (name, handle, city, Honduras local toggle). Custom `FTField` styled to match design tokens.
- `RootView` now renders `AuthView` for `signedOut`; placeholder removed.

**Decisions**

- SIWA returns Apple's name components; we pre-fill `displayName` from there to skip a step for first-party users.
- Profile setup is mandatory after signup so `profiles` is never empty server-side; PRD requires display name + Honduras toggle from day one.

---

## 2026-05-06 — Milestone 8: Data layer (DTOs + mapping + repositories)

**What landed**

- `Data/DTO/DTOs.swift` — Codable DTOs (snake_case) for every domain entity.
- `Data/Mapping/Mappers.swift` — DTO → domain extensions; ISO date helpers; `JSONDecoder.supabase`.
- `Data/Repositories/`: `ProfileRepository`, `CigarRepository` (with `CigarFilters` and `or()` ilike search), `DrinkRepository`, `RoomRepository` (list/fetch/create/join/leave/setPresence), `MessageRepository` (paged history with cursor on `created_at`, send with client-supplied `id` for idempotency, edit/soft-delete, toggle reaction), `SessionRepository` (start/finish/saveSummary), `UsualRepository`, `SocialRepository` (connections, request/respond, chemistry view), `EventRepository` (list/create/RSVP), `DropRepository` (current + upcoming).

**Decisions**

- All repositories are protocol-first — gives us mockable seams for tests and lets feature ViewModels compile against `protocol P` in test injection.
- Message send uses a client-provided UUID — server inserts with that id, which gives the realtime delivery the same id we used for the optimistic row, so dedupe just works.
- Soft-deleted messages are filtered at the repository layer (`is("deleted_at", nil)`).
- `ConnectionChemistry` reads from the `connection_chemistry` view (M2). Promote to materialized if profiling shows it's hot.

---

## 2026-05-06 — Milestone 9: Explore tab

**What landed**

- `Features/Explore/ExploreViewModel.swift` — `cigars/drinks` mode toggle, debounced (220 ms) search, filter state.
- `Features/Explore/ExploreView.swift` — header, capsule mode picker (gold-on-fill for active), search field, list with `LazyVStack`, `FiltersSheet` covering strength/wrapper/country.
- `Features/Explore/CigarDetailView.swift` — hero (brand caps + display name + vitola), facts card (country/wrapper/strength/size), origin story, fun fact, flavor notes via custom `FlowLayout`.
- Wired into `MainTabView`: Explore tab now opens a `NavigationStack` with destination for `AppRoute.cigar(...)`.

**Decisions**

- `FlowLayout` is implemented as a SwiftUI `Layout` — keeps the chip wrap responsive and avoids `WrappingHStack` dependencies.
- Filter sheet uses native `Form` for system-consistent dark UI without re-skinning controls.
- Cigar list is virtualized via `LazyVStack` — chat + Explore are the two scroll-heavy surfaces and both use it.

---

## 2026-05-06 — Milestone 10: Lounge base + Room view (chat, presence, optimistic outbox)

**What landed**

- `Features/Lounge/LoungeViewModel.swift` + `LoungeView.swift` — room list with active-dot indicator, occupant capsule, empty state ("Quiet so far tonight."). Tapping a room navigates to `RoomView`.
- `Features/Room/RoomViewModel.swift` — owns room/messages/presence, ghost toggle, draft text, optimistic send (UUID generated client-side, marked `pending` then replaced with synced row from server), pagination via `loadOlder()`, realtime stream subscription with auto-dedupe through `RealtimeService`. Arrival haptic on non-ghost presence joins.
- `Features/Room/RoomView.swift` — header with theme, horizontal `PresenceRail` (avatars with active gold ring + ghost dim), `ChatList` with `ScrollViewReader` auto-scroll, `MessageRow` (with pending opacity + failed reason), `ComposerBar` (gold send button, soft tap haptic).

**Decisions**

- Decided to ship with `LazyVStack` for chat (Engineering Rules call out `UITableView` wrapper as an option). On iOS 17 this keeps a stable scroll position with `ScrollViewReader.scrollTo` and avoids the UIKit bridge until profiling proves we need it. If profiling on iPhone 11 with 1k messages shows jank, we drop in a `UIViewRepresentable` over `UITableView` behind the same `ChatList` view.
- Optimistic message rows are visually de-emphasized (55 % opacity) so users see clearly that they're in flight without flickering.
- `loadOlder()` is triggered by an invisible `Color.clear` at the top of the stack — simple and avoids an explicit "load more" button.

---

## 2026-05-06 — Milestone 11: Session system (start/stop, burn timer, summary)

**What landed**

- `Features/Session/SessionViewModel.swift` — phase state machine (`selectingCigar → selectingDrink → lighting → active → summary → finished`), wraps `SessionRepository`, owns a `tickerTask` that polls `currentThird()` every 15 s and triggers `playFinalThirdPattern` on transition into the final third.
- `Features/Session/SessionFlowView.swift` — entire entry flow: cigar picker → drink picker (with "Skip the drink") → lighting method chooser (Match / Torch / Cedar / Soft Flame) → Lighting Ceremony → Active session → Summary.
- `Features/Session/BurnTimerView.swift` — gold-and-ember progress ring with elapsed + third label; switches to gold border with `goldPulse` animation in the final third (PRD identity moment).
- `Features/Session/SessionSummaryView.swift` — flavor / draw / overall star ratings, would-smoke-again toggle, mood slider (1–10), unwind toggle, free-text notes, save-and-step-out CTA.

**Decisions**

- 15 s polling for third transitions is light and avoids redundant work. The visual ring updates every 1 s via a Timer publisher only inside `BurnTimerView` (kept local to avoid VM churn).
- Skip-drink path is first-class — pairing is optional in the PRD.
- Star tap fires `HapticsService.tap()` — small ritual reinforcement matters here.

---

## 2026-05-06 — Milestone 12: Lighting Ceremony

**What landed**

- `Features/LightingCeremony/FlameCanvas.swift` — procedural flame in a `TimelineView`-driven `Canvas`. Layers: ember halo (radial gradient), three sinusoidal-lobe flame body with vertical gradient, bright core sliver, deterministic rising sparks. `intensity: 0...1` controls overall scale + brightness; `blendMode(.plusLighter)` for additive feel.
- `Features/LightingCeremony/LightingCeremonyView.swift` — full-screen choreography over ~6 s:
  - 0.0–0.4: vignette in.
  - 0.2–0.8: lighting tool (match/torch/cedar/soft flame) slides up from below.
  - 0.0 (immediate): `playLightingPattern()` haptic — ignition tick + 1.4 s rumble + settle pulse.
  - 0.9–1.8: flame ramps in, breathes ±10 % (`sin(t·2.4)`).
  - 1.8–2.4: tool fades out.
  - 3.0: cigar brand caps + display name + vitola fade in.
  - 5.5: "Tap to take your seat." prompt breathes; tap completes.
- Reduce Motion path: replaces flame Canvas with a static `flame.fill` SF Symbol gradient. Vignette and copy reveal still happen.
- VoiceOver: collapses to a single accessible button labeled "Lighting your [cigar name]. Double tap to enter." — completes the ceremony on activation.
- Analytics fires `lightingCeremonyShown(method:)` on appearance and `lightingCeremonyCompleted` when the tap lands.

**Decisions**

- **Canvas, not Metal, for v1.** Procedural Canvas+TimelineView holds 60 fps on iPhone 11 and avoids a Metal asset budget. The plan reserved a Metal fallback for later — we'll only escalate if profiling shows headroom is thin. Quality is excellent at this scale because the flame is small relative to the screen and additive blending hides aliasing.
- Sparks are deterministic per-frame (seeded by `i`) so the result is repeatable and testable, with no PRNG state to manage.
- The settle prompt only becomes tappable after 5.5 s — prevents accidental skip during the emotional peak.
- No Lottie. The flame is too critical to outsource to an animator's intent.

**Open**

- Audio cues (match strike + flame whoosh + low ember bed): files need to be sourced/licensed; engine is ready (`AudioEngine.load(theme:)` reads from `Resources/Sounds`). Ship in M14 alongside ambient themes.
- Snapshot tests for ceremony key frames at 0.5 s / 1.5 s / 3.5 s — defer to test pass.

---

## Open items (next milestones)

- M13: Journal (history list, stats, weekly recap, premium gate at 30 sessions).
- M14: Home tab (greeting, Tonight's Pick, Active Rooms, Your Ritual, Drop of the Week, Nearby Tonight) + audio assets for Lighting Ceremony + ambient themes.
- M15: Profile + Social (profile screen, connections, Chemistry, badges).
- M16: Events + Drops surfaces.
- M17: Paywall (RevenueCat) and gate wiring.
- M18: Audio + Voice integration in `RoomView` (ducking + LiveKit token edge function).
- M19: Final polish, accessibility, snapshot/UI tests, performance pass.

## Risks logged

- **Supabase Swift SDK API drift** — `postgresChange` / `presenceChange` shapes change across minor versions. Pin once we boot the project locally; if the SDK is on 2.x and types don't match, refactor `RealtimeService` accordingly.
- **AVAudioSession + LiveKit interplay** on real devices — needs route-change observers and category transitions when voice joins. Will land alongside voice in M16.
- **Swift 6 strict concurrency** with Supabase + LiveKit — both SDKs are still tightening Sendable annotations; expect a few `@unchecked Sendable` shims at integration time.
