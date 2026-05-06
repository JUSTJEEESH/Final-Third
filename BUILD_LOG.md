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

## Open items (next milestones)

- M7: Auth feature (full sign-in screen, email path, onboarding/profile setup, Honduras toggle).
- M8: Repositories (CoreData mirror + Supabase fetch) for Profile/Cigar/Drink/Room/Message/Session/Usual/Connection/Event/Drop.
- M9: Explore tab (search, filters, Cigar Detail, Drink Detail).
- M10: Lounge base (room list, chat with optimistic outbox + dedupe, presence rail).
- M11: Session system (start/stop, burn-timer thirds, Final-Third gold pulse, Session Summary).
- M12: Lighting Ceremony (Metal flame + emitter sparks + haptic + audio).
- M13–M17: Journal, Home, Profile/Social, Events, Drops, Paywall, Voice + Ambient wiring, polish.
- Tests: AuthService, OfflineQueue, RealtimeService dedupe, repository round-trips, snapshot tests for design system.

## Risks logged

- **Supabase Swift SDK API drift** — `postgresChange` / `presenceChange` shapes change across minor versions. Pin once we boot the project locally; if the SDK is on 2.x and types don't match, refactor `RealtimeService` accordingly.
- **AVAudioSession + LiveKit interplay** on real devices — needs route-change observers and category transitions when voice joins. Will land alongside voice in M16.
- **Swift 6 strict concurrency** with Supabase + LiveKit — both SDKs are still tightening Sendable annotations; expect a few `@unchecked Sendable` shims at integration time.
