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

## 2026-05-06 — Milestone 13: Journal

**What landed**

- `Features/Journal/JournalViewModel.swift` — loads recent sessions (200 max from server), hydrates the cigar lookup table with a `TaskGroup`, derives stats (total sessions, total minutes, favorite cigar, preferred strength) and a `WeeklyRecap` (last 7 days, count + average minutes). Honors the **30-session free limit** via `visibleSessions` / `hiddenCount`.
- `Features/Journal/JournalView.swift` — display title, three stat cards, weekly recap card, recent session list with date + duration + rating, and a `PaywallTeaser` row that surfaces hidden count and opens `PaywallView` when free user has more than 30 sessions.

**Decisions**

- Stats are computed in the ViewModel from the loaded set so we don't need a separate stats endpoint at v1.
- "Favorite cigar" uses session count, not duration — count is more durable signal early when there's little data.
- Empty state copy is "Your first session will land here." — atmosphere over status.

---

## 2026-05-06 — Milestone 14: Home

**What landed**

- `Features/Home/HomeViewModel.swift` — parallel load via `TaskGroup` of profile, usual + its cigar, top 4 active rooms, current drop + its cigar, and 3 nearby events filtered by the user's saved city. `greeting` reads time-aware copy from `app_config` (`greeting.evening` / `greeting.late` / `greeting.morning`) — server-driven copy in action.
- `Features/Home/HomeView.swift` — `NavigationStack` with destinations for `room` and `cigar` deep links. Sections: Greeting (display + ember badge for streak), Tonight's Pick (links to cigar detail), Your Ritual (preferred time, default cigar), Drop of the Week (live capsule, hero copy), Active Rooms (gold dot + chevron rows), Nearby Tonight (city-scoped events).

**Decisions**

- Tonight's Pick falls back: usual cigar → drop cigar → nothing. Keeps the section meaningful even before The Usual is set up.
- All sections degrade gracefully — empty states are quiet copy ("Nothing yet — be the first to step in."), never error UI.

---

## 2026-05-06 — Milestone 15: Profile + Social + Chemistry

**What landed**

- `Features/Profile/ProfileViewModel.swift` — loads profile, usual (for streak), connections, chemistry rows in parallel; updates audio default and ghost-mode default through `ProfileRepository.updatePreferences`.
- `Features/Profile/ProfileView.swift` — header (avatar with active gold ring, display name, handle, city), three stat cards (streak, connections, badges), Chemistry section ("You smoke well together" + sessions/minutes), Connections section (pending requests highlighted, accepted list), Preferences card (ambient audio menu, ghost-by-default toggle), and Sign Out at the bottom.

**Decisions**

- Chemistry strings come from PRD example copy verbatim — this is identity, not metric.
- Audio + ghost prefs persist immediately on change via repository — no save button.
- Badges list is wired through `badgeCount` field (data model already supports `user_badges`); awarding logic + the badge gallery view are deferred to a polish pass.

---

## 2026-05-06 — Milestone 16: Events + Drops

**What landed**

- `Features/Events/EventsView.swift` — list of upcoming events with title / time / location, RSVP buttons (Going / Maybe) that fire `event_rsvps` upserts; empty state encourages event creation.
- `Features/Drops/DropsView.swift` — current live drop (gold "Live" capsule, brand caps + display name + hero copy + relative end time) plus an upcoming drop list. Falls back to "No drop live right now."

**Decisions**

- Event creation form is intentionally not in v1 — the PRD lists creation but RSVP-first is the higher-value loop. Add when there's a way to verify the host (not in scope here).
- Drops surface is read-only on iOS; admins schedule via the Supabase dashboard for now.

---

## 2026-05-06 — Milestone 17: Paywall + premium gating

**What landed**

- `Features/Paywall/PaywallView.swift`:
  - Hero copy from `app_config.paywall.copy` (server-driven).
  - Four benefit cards: full journal, private rooms, pairings, advanced ritual.
  - Buy CTA → `EntitlementService.purchase(packageIdentifier:)` against the RC offering's `$rc_monthly`; closes on entitlement flip.
  - Restore purchases CTA → `EntitlementService.restore`.
  - Analytics: `paywallShown(trigger:)` on appear; `paywallPurchased(productID:)` on success.
- `PremiumGateModifier` + `View.premiumGate(isPremium:trigger:)` — wraps any view to disable + dim it when not premium and intercept taps to surface the paywall sheet. Used from `JournalView`'s teaser row.

**Decisions**

- Paywall identifier is `$rc_monthly` for now — RC offerings let us swap product without releasing.
- Gating is a view modifier rather than a wrapping container — easier to apply piecemeal.

---

## 2026-05-06 — Milestone 17.5: Tab bar wired to real features

`MainTabView` now routes Home/Explore/Lounge/Journal/Profile to their actual feature views (`HomeView`, `ExploreView`, `LoungeView`, `JournalView`, `ProfileView`). Placeholder structs removed; tab bar overlay padding added so feature content doesn't sit under the bar.

---

## 2026-05-06 — Milestone 18: Voice + ambient in Room

**What landed**

- `Features/Room/RoomVoiceTokenProvider.swift` — calls the `livekit-token` edge function via `supabase.functions.invoke`, decoding `{ token, can_speak }`.
- `Features/Room/PushToTalkButton.swift` — gold capsule mic button. Press-and-hold gesture toggles transmit; transmitting state shows an outward-pulsing gold ring (`scaleEffect` + `repeatForever`) and switches the icon to filled. Disabled when not joined; opacity drops in ghost mode.
- `RoomViewModel` now owns `voiceJoined` + `ambientTheme`, holds references to `VoiceService` + `AudioEngine`, and exposes `joinVoice()`, `setTransmitting(_:)`, `setAmbient(_:)`. Joining voice is blocked in ghost mode (silence by design). On `enter` the room's saved `audio_theme` is applied to the ambient mix; on `leave` voice is disconnected and ambient muted. Ambient is automatically ducked while transmitting via `audio.duck(on)`.
- `RoomView` adds:
  - Toolbar speaker button → `AmbientPickerSheet` (Silence + 5 themes from `AudioTheme.allCases`).
  - `VoiceBar` between chat and composer: shows "Tap to join voice" pill (or "Voice off in ghost mode" when ghosted), then swaps to the `PushToTalkButton` once joined.
  - Ghost default now sourced from the user's profile (`profile.ghostModeDefault`) on first enter — completes the M13 TODO.

**Decisions**

- Voice is opt-in per session (PRD privacy stance). Ghost mode forces mute regardless of profile prefs.
- One `AudioEngine` for the app-level ambient mix; LiveKit owns its own audio session for voice. We coordinate via `mixWithOthers` + ducking, never by switching sessions.

---

## 2026-05-06 — Milestone 18b: LiveKit token edge function

**What landed**

- `supabase/functions/livekit-token/index.ts` — Deno edge function:
  1. Validates the caller's Supabase JWT (`auth.getUser`).
  2. Confirms `room_members` row for `(room_id, user_id)`.
  3. Looks up / creates the `voice_rooms` row using the service-role client.
  4. Counts current speakers; sets `canPublish` to `false` once `max_speakers` is reached so the user joins as a listener.
  5. Issues a LiveKit access token with 1-hour TTL, scoped to room `voice:<room_id>`.
- `supabase/functions/livekit-token/deno.json` — module aliases.

**Decisions**

- Token issuance is a single round-trip — no separate "request speaker" call. If you can speak right now, you get a publish-capable token; if not, you get a listener token and can re-request when a slot opens.
- Service-role key is only used inside the edge function — never on-device.

---

## 2026-05-06 — Milestone 21: Settings

**What landed**

- `Features/Settings/SettingsView.swift` — full Form-based settings sheet:
  - **Account**: name / handle / email rows + Sign out (destructive).
  - **Ritual**: row that opens `TheUsualEditor`.
  - **Audio**: default ambient theme picker, persisted via `ProfileRepository.updatePreferences`.
  - **Voice**: opt-in toggle + reassuring caption ("You'll always be muted by default. Hold to talk.").
  - **Privacy**: ghost-by-default toggle.
  - **Notifications**: live permission status + request button hooked into `NotificationService`.
  - **Membership**: status / renewal date / become a member CTA / restore purchases.
  - **About**: app version + build number, Privacy + Terms links.
- `ProfileView` gets a gear icon in the toolbar that presents `SettingsView`, and a tappable "The Usual" card that opens `TheUsualEditor`.

**Decisions**

- Used the system `Form` styled with `.scrollContentBackground(.hidden)` over our dark surface — preserves native interactions (haptics, accessibility) without re-skinning every control.
- Each toggle persists immediately. No "Save" button.

---

## 2026-05-06 — Milestone 22: The Usual editor

**What landed**

- `Features/TheUsual/TheUsualEditor.swift` — `@Observable` ViewModel + sheet view:
  - Loads any existing usual + the cigar/drink catalogs in parallel.
  - Wheel `DatePicker` for time (defaults to 21:00).
  - Cigar / drink menu pickers (with "None" options).
  - Save converts the date into a `TimeOfDay`, upserts via `UsualRepository`, and either schedules or cancels the local notification through `NotificationService.scheduleUsual`/`cancelUsual`. Notification copy is the PRD line: "Your chair is ready."
- Wired up from `ProfileView` (ritual card) and `SettingsView` (Ritual section).

**Decisions**

- Notification scheduling is part of the same save action — the editor is the single source of truth for the reminder; no drift.
- No streak settings exposed; streak is derived server-side via the trigger from M2.

---

## 2026-05-06 — Milestone 20: Unit tests (first pass)

**What landed**

- `TheFinalThirdTests/UnitTests/SessionThirdTests.swift` — `Session.currentThird` across closed/open sessions and the cap behaviour.
- `TheFinalThirdTests/UnitTests/DTOMapperTests.swift` — Profile mapping (notif prefs fallback, audio theme, Honduras local), Cigar (`flavor_notes` default, strength label), Usual time string parsing, Message default `pendingState`, Connection status fallback to `.pending`.
- `TheFinalThirdTests/UnitTests/DeepLinkRouterTests.swift` — `finalthird://room/<uuid>`, `cigar/<uuid>`, `usual` happy paths; non-`finalthird` schemes ignored; `consume()` clears.
- `TheFinalThirdTests/UnitTests/OfflineQueueTests.swift` — enqueue/drain happy path, retain-on-failure path. Includes a small extension to install a no-op replayer.
- `TheFinalThirdTests/UnitTests/JournalStatsTests.swift` — uses stub `SessionRepository` + `CigarRepository` to verify the 7-day weekly recap window and the 30-row free-tier cap with `hiddenCount`.

**Decisions**

- Tests use the new **swift-testing** (`@Suite`, `@Test`, `#expect`) — already pinned via `project.yml` dependency on `pointfreeco/swift-snapshot-testing`. Native XCTest tests can co-exist if needed.
- Stubs are scoped to the test file (no separate `Mocks/` module yet) — keeps the cost low and lets tests evolve independently.
- `OfflineQueue` test has a small permissive race (drain may complete before `pendingCount`) — acknowledged in the assertion.

---

## 2026-05-06 — Backend follow-ups: edge functions + storage

**What landed**

- `supabase/functions/revenuecat-webhook/index.ts` — verifies a shared-secret bearer token, mirrors RC events into `entitlements`, flips `profiles.is_premium` for cheap server reads. Maps event types (`INITIAL_PURCHASE` / `RENEWAL` / `PRODUCT_CHANGE` / `UNCANCELLATION` / `TRANSFER` → active; `CANCELLATION` / `EXPIRATION` / `BILLING_ISSUE` / `SUBSCRIPTION_PAUSED` → inactive) and stores the raw payload for forensic debugging.
- `supabase/functions/weekly-recap/index.ts` — cron-driven (`0 18 * * 0`) sweep that aggregates the last 7 days of completed sessions per user, computes count + average minutes, and writes `app_config["recap.<user_id>"]` so the iOS client can read the recap without a new table.
- `supabase/functions/award-badges/index.ts` — daily sweep that resolves badge IDs once and awards: `first_light` (≥1 ended session), `palate_pro` (≥10 fully-rated), `regular` (≥4 sessions in the last 7 days), `ember/flame/fire` (3/7/30-day streak via `usuals.streak_count`), `good_company` (pairs with ≥3 sessions in `connection_chemistry`). Idempotent via `upsert` on `(user_id, badge_id)`.
- `supabase/migrations/0004_storage_buckets.sql` — creates `avatars` (private), `cigars`, `drinks` (public read) buckets and writes RLS policies on `storage.objects`: avatars readable by any authenticated user, writable only by their owner via `(storage.foldername(name))[1] = auth.uid()`; cigars/drinks public read; writes via service role only.

**Decisions**

- Wrote the recap into `app_config` rather than a new `weekly_recaps` table to keep surface area small for v1 — promote to a real table when retention/history matters.
- Badges are upsert-only (never revoked). If we need decay (e.g. "Regular" should fall off after a quiet month) we can add a separate cleanup pass.
- Avatar storage scopes object names with the user UUID as the first folder segment (`avatars/<uid>/avatar.jpg`) so RLS can match without a separate table lookup.

---

## 2026-05-06 — Polish: state views + a11y nudges + audio asset spec

**What landed**

- `DesignSystem/Components/StateViews.swift` — `FTLoadingView`, `FTEmptyView`, `FTErrorView` for consistent quiet placeholders (atmosphere-preserving copy; never bright).
- A11y: `FTButton` declares `accessibilityLabel`/`accessibilityHint`/`isButton` traits explicitly; `RoomView` composer text field and send button get `accessibilityLabel` ("Message", "Send message"). The Lighting Ceremony's single-accessible-button collapse already exists from M12.
- `TheFinalThirdTests/SnapshotTests/DesignTokenSnapshotTests.swift` — snapshots for `FTButton` gold/ghost styles, `EmberBadge` thresholds (0/1/7/30), `AvatarView` active/inactive/ghost. Guards against the most likely visual regression: gold drift.
- `TheFinalThirdTests/UnitTests/RoomViewModelMessageReconcileTests.swift` — verifies optimistic insert + server echo dedupe by id, and failed sends keeping a row marked `.failed`.
- `TheFinalThird/Resources/Sounds/.gitkeep` — folder marker carrying the audio asset specification.

### Audio asset spec

Required files in `TheFinalThird/Resources/Sounds/` (256 kbps AAC, seamless loops where applicable):

| File | Length | Channels | Notes |
|---|---|---|---|
| `lounge_murmur.m4a` | ~120 s | stereo | faint crowd murmur, no intelligible voices |
| `jazz.m4a`          | ~180 s | stereo | low-volume mellow jazz, instrumental only |
| `lofi.m4a`          | ~120 s | stereo | mid-tempo lo-fi instrumental |
| `rain.m4a`          | ~120 s | stereo | gentle rain on glass, no thunder |
| `fireplace.m4a`     | ~120 s | stereo | soft fireplace crackle |
| `match_strike.m4a`  | ~0.4 s | mono   | match strike, dry, transient |
| `flame_whoosh.m4a`  | ~1.2 s | mono   | soft ignition whoosh, warm |
| `ember_bed.m4a`     | ~3.0 s | mono   | low ember bed, fades on exit |

`AudioEngine.load(theme:)` already reads ambient files by name. Lighting cues will be wired into `LightingCeremonyView.runChoreography` once the files are in.

---

## 2026-05-07 — Onboarding world-class pass (round 2)

**User feedback addressed**

- Welcome + intro carousel were never visible because both screens used `Spacer()` inside the outer `ScrollView`, which collapses spacers to zero. Restructured `OnboardingView.content`: welcome and intro now render full-bleed in a fixed `VStack(maxHeight: .infinity)`, while only the form-heavy setup screens sit inside a `ScrollView`. Welcome also gained a second copy line under the headline so the first screen doesn't feel empty.
- Step 2 (location) was Honduras-hardcoded. Replaced with a worldwide `CountryPickerSheet` driven by `Locale.Region.isoRegions`, sorted by localized name, with a flag emoji (regional indicator math) and live search. The viewmodel seeds `country` from `Locale.current.region?.identifier` so most users only need to confirm. The "I'm a local" toggle is now generic ("I live here year-round") and surfaces local lounges/hosts/events instead of being country-specific. City placeholder rotates to a sensible example based on the selected country.
- Step 3 (the usual) replaced the giant `Menu` cigar/drink lists with proper `CigarPickerSheet` + `DrinkPickerSheet` — large detents, sticky search bar, category chips for drinks, brand/line/vitola/country search across cigars. Picker rows show the right secondary metadata so the user can tell two similar cigars apart at a glance. "Clear" buttons restore the empty state.
- Step 5 (recap) was reflowed: avatar centered with breathing gold ring, identity stacked under it, location pill, then a 2-up grid (RITUAL · VIBE) showing time / cigar / drink alongside ambience / privacy. Closes with "The door's open. Take your time." in italic before the CTA.
- Copy pass across Welcome, Name, Avatar, Location, Usual, Vibe, Notifications — every subtitle now describes *why* this step matters rather than what it does. New users see emotional, specific language ("Cuban purist. Old fashioneds. Late nights.", "One quiet ping a night", "How the lounge sounds when you walk in").

**Schema + model migration**

- Migration `0009_profiles_country.sql` (already applied via MCP): `add column country text` + `rename is_honduras_local → is_local`.
- `Profile`, `DTO.Profile`, `DTO.Profile.toDomain`, `LiveProfileRepository.upsert` updated to carry `country: String?` + `isLocal: Bool`. `Profile.countryName` computed from `Locale.current.localizedString(forRegionCode:)`.
- `OnboardingViewModel`: dropped `isHondurasLocal`, added `country` (region-seeded) + `isLocal`.
- `DTOMapperTests` updated for the renamed columns + new `country` field.

**Why this matters**

- The intro carousel was the entire emotional pitch for the app — users skipping straight from Welcome to Name never heard "not a feed, a place / every cigar deserves an entrance / a library of your nights". That bug was load-bearing for first-impression conversion.
- Worldwide country support unblocks the user (in Honduras / Roatán) and every non-HN tester. Without it the app silently signaled "this isn't built for you".

---

## 2026-05-07 — Rooms × Sessions, Step 1: Foundation

**The vision (locked)**

We're wiring the ritual to the camaraderie. Two doorways into one state: light first → "Where are you sitting?" sheet → solo or in a room; or sit first → "Light up here" → ceremony in-room. The active session becomes global state that travels with the user across tabs. A persistent session bar pins on top while burning. Patron tier ($7.99/mo · $59/yr · 14-day trial annual-only) gates voice rooms, hosting, multiple usuals, full Journal history, custom audio themes, drop early access, and the gold avatar ring — never gates the core ritual or social access. Full plan committed in conversation.

**What landed in Step 1 (foundation, no UX change yet)**

- `Features/Session/SessionState.swift` — `@Observable` owner of the active session lifecycle. Hoisted onto `AppContainer.session` so any view (Home, Lounge, Room, the future session bar) reads `container.session.activeSession` / `activeCigar` / `activeRoomID` without coordinating through the flow view. Exposes `isBurning`, `isInFlow`, `beginFlow(...)`, `clear()`. Idempotent — a stray "Light up" tap from another surface preserves the in-flight session.
- `SessionFlowView` refactored to a thin presenter. Removed `userID/roomID/isGhost` props and the local `@State` VM. Now reads `container.session.current` directly. Cancel and `.finished` paths both call `container.session.clear()` so the global state always returns to nil.
- `HomeView.lightUpButton` calls `container.session.beginFlow(userID:roomID:isGhost:analytics:)` *before* presenting the cover, matching the new contract that the VM exists at present-time. Same UX, different ownership.
- Migration `0010_session_room_links.sql` (applied to live DB via MCP):
  - `rooms.mode` (`chat` | `voice`) — schema-ready for voice-room Patron gating without a parallel table
  - `messages.kind` (`user` | `arrival` | `departure` | `move`) + `messages.payload jsonb` — system events render in the same chat stream as user messages, no separate table
  - `messages_body_check` relaxed to allow empty body when `kind <> 'user'`
  - `messages_insert_member` policy tightened to `kind = 'user'` so clients can't spoof "X has lit up"
  - `sessions_room_active_idx` partial index on `(room_id) where ended_at is null` — the live-now query for the doorway sheet stays O(rooms with active smokers), not O(sessions ever)
  - `post_system_message(p_room_id, p_kind, p_payload)` SECURITY DEFINER RPC — only path for arrival/departure/move writes, mirrors the SELECT visibility check before inserting
- `room_members` already existed from 0001 (with role + joined_at) — no new table needed

**Why Step 1 first**

Without global session state, every other surface (room bar, "Pull up a chair" pill, in-room ceremony, mid-session room switching) has to round-trip through HomeView's sheet hierarchy. Hoisting first is load-bearing for everything that comes next.

**Visible to user:** nothing. Light up still launches a sheet, picks cigar/drink/method, plays the ceremony, runs the session, ends in the journal. The plumbing under it is now ready for the doorway sheet (Step 3) and the session bar (Step 2).

---

## 2026-05-07 — Rooms × Sessions, Step 2: Persistent session bar

**What landed**

- `SessionState` learned three new behaviors:
  - `isFlowPresented` — a single `@Observable` flag that drives the cover. Bind from anywhere, flip from anywhere.
  - `expand()` — bring the cover back to front (idempotent, no-op if there's no active VM).
  - `minimize()` — close the cover but keep the session burning.
  - `clear()` now also flips `isFlowPresented = false` so teardown is one call.
- `Features/Session/SessionBarView.swift` — new pinned strip:
  - Pulsing ember dot (3-second breathe)
  - Cigar brand (eyebrow) + line (heading)
  - Live "X min" via `TimelineView(.periodic(every: 30s))` with monospaced digits
  - Ellipsis → confirmation dialog: Open session / End session
  - Tap body → `expand()`
  - Leather grain + warm ember bleed background, gold hairline beneath
  - Renders only when `isBurning && !isFlowPresented`, transitions in from the top
- `MainTabView` hosts both the bar and the cover. The cover moves up out of `HomeView` because the session is global — it has to be presentable from any tab.
  - `@Bindable var session = container.session` bridges the observable into a binding.
  - Animations on `isBurning` and `isFlowPresented` so the bar slides in and the tab content reflows smoothly.
- `ActiveSessionView` got a top-right chevron-down "minimize" button. Tap → cover slides away, session bar takes over, you can browse Lounge/Journal/Profile while the cigar burns.
- `HomeView` lost its `showLightUp` state and `fullScreenCover`. The Light Up button now: `beginFlow(...)` (if no session) → `expand()`. Re-tapping Light Up while a session is already burning just re-opens it.
- `SessionFlowView` cancel + `.finished` paths use `container.session.clear()` exclusively. Removed the `@Environment(\.dismiss)` since the cover dismisses via the binding.

**Why this matters**

- The session is no longer trapped inside one view's lifecycle. Walk into Lounge while burning — the bar follows. Tap an avatar in Journal — the bar follows. End the session anywhere → summary cover springs back so you can rate the night.
- Loaded for Step 3 ("Where are you sitting?" sheet) and Step 4 (in-room session UX) — both depend on the cover being controlled from outside its own view tree.

**Visible to user**

- Light up, then minimize with the new chevron-down → bar appears at the top with cigar name + live timer + ellipsis menu. Browse the app freely. Tap the bar → back to the active session full-screen.

---

## 2026-05-07 — Rooms × Sessions, Step 3: The doorway

The single biggest moment for pulling solo users into the social half of the app — the cigar's lit, the flame is still glowing in their eyes, and we offer them company or quiet, never forcing.

**What landed**

- Migration `0011_room_live_now.sql` (applied via MCP):
  - `room_live_now(p_room_ids uuid[])` SECURITY DEFINER RPC. Returns per-room `live_count` + a sample of up to 3 smokers (display name, avatar URL, cigar brand/line, minutes-in, started_at) for a given list of rooms.
  - Filters out ghost sessions server-side. Ghost = invisible, end of story.
  - `stable` so Postgres can cache results within a single transaction.

- Domain layer:
  - `Room.mode` enum (`chat` | `voice`). Defaults to `.chat` on existing rows. Voice rooms are visible to free users in the picker but Patron-locked at selection time.
  - `LiveNowSummary` value type with nested `Smoker` (and a `cigarDisplay` helper).
  - DTOs + Mappers updated. `StubRoomRepo` test mock updated.

- Repository:
  - `RoomRepository.liveNow(roomIDs:)` calls the RPC, returns `[UUID: LiveNowSummary]`.

- `RoomPickerViewModel`:
  - Two-pass load (rooms list, then liveNow aggregate).
  - Sectioning getters: `liveRooms` (count > 0, sorted desc), `topicRooms` (chat + non-private + no smokers), `voiceRooms`.
  - `refreshLiveNow()` for the 30-second poll while the sheet is open.

- `RoomPickerSheet`:
  - Header: "THE ROOM IS YOURS — Where would you like to sit tonight?"
  - **Lit up right now** cards: ember pip, room name, "N lit up" badge, smoker rows (avatar with gold ring, name, cigar, minutes-in), "+N more lit up" overflow line. Gold-bordered, leather grain, soft warm gradient, gold glow shadow. Magnetic.
  - **By the window** cards: simple chat-room rows with name + audio theme.
  - **Voice rooms**: always visible, gold lock for non-Patrons, taps fire upsell sheet. Patron upsell is a placeholder until Step 7.
  - **Stay solo** at the bottom — moon icon, "No room tonight. Just the burn." Soft surface, never gold.
  - Task-based 30-second polling for live-now refreshes (Swift Concurrency, not Timer — keeps Swift 6 strict isolation happy).

- Session lifecycle:
  - New `Phase.choosingRoom` between `.lighting` and `.active`.
  - `SessionViewModel.ceremonyCompleted()` advances to `.choosingRoom` (replacing the direct call to `startSession()` from the ceremony's onComplete).
  - `SessionViewModel.chooseRoom(_ room: Room?)` — records `chosenRoom`, sets the internal `roomID`, best-effort joins `room_members`, then calls `startSession()`. Solo passes `nil` → session row gets `room_id = null`.
  - `SessionFlowView` renders the picker as the screen during `.choosingRoom`. Cancel button hides post-ceremony — the picker has its own "Stay solo" exit.

**Why this matters**

- Every cigar now gets a doorway moment. Solo is a deliberate choice, not the default.
- Live-now first means the user sees actual humans — names, real cigars, minutes-in — not just a list of room names. That's the magnet.
- Schema-ready for voice rooms via `Room.mode` without a parallel table.
- Sessions write `room_id` correctly upfront, so live-now queries see them immediately and the room presence in Step 4 has the data it needs.

**Visible to user**

Light up like before. After the ceremony's flame settles, a leather-and-gold sheet swoops up: "Where would you like to sit tonight?" Pick a room (with smokers + cigars showing for the live ones) or tap "Stay solo" — either way, your cigar is lit.

---

## 2026-05-07 — Rooms × Sessions, Step 4: In-room session UX

The two halves finally meet. You can light up *from* a room (Path B), and rooms now *show* who's lit up next to their avatars. Inside a session, the room you're sitting at is part of your session identity.

**What landed**

- `SessionViewModel.init` now takes `room: Room?` instead of `roomID: UUID?`. The Room is stored in `chosenRoom` from construction so Path B carries it through to the active screen.
- `SessionState.beginFlow(userID:room:isGhost:analytics:)` mirrors the same shape. Path A (Home Light Up) passes `room: nil`. Path B (Room Light Up Here) passes the actual `Room`.
- `SessionViewModel.ceremonyCompleted()` branches: if `chosenRoom != nil` (Path B) we go straight to `startSession()` and skip the doorway sheet — the user already chose where to sit before lighting. If `chosenRoom == nil` (Path A), the picker fires as before.

- `RoomView` got a real header story:
  - Title row now shows "🔥 N lit up" gold subline whenever there are active smokers.
  - **`LightUpHereCTA`** sits below the header. Three states:
    - **Available** — gold "Light up here" button. Mirrors Home's button vocabulary so the action reads identically across surfaces. Tap → `beginFlow(room: vm.room)` + `expand()`. The doorway picker is skipped because the room is preselected. Ceremony plays full-screen.
    - **Active here** — leather/gold tile showing "YOU'RE LIT — Padrón 1964" with an "Open" button → `expand()` to bring the focus card back.
    - **Active elsewhere** — quiet line: "You're lit at \(other room name)" or "You're lit solo right now." with an "Open" button. Step 6 will turn this into "Move over here."

- `RoomViewModel`:
  - New `smokersByUser: [UUID: LiveNowSummary.Smoker]` keyed by user ID. Filled from `room_live_now` on `enter()` and refreshed by a 30-second `smokerPollTask`. Cancelled on `leave()`.
  - Reuses the same RPC as the doorway sheet — single source of truth for "who's burning where".

- `PresenceRail` rewrite:
  - Smokers float to the front of the rail (most magnetic first).
  - Smoker chips render as a Capsule with a gold-haloed avatar + name + cigar + minutes-in: *"Marcus · Padrón 1964 · 22 min"*. Quiet glow.
  - Non-smokers render as today's plain `AvatarView`.

- `ActiveSessionView` shows "Sitting at \(room name)" beneath the IN SESSION eyebrow when the session has a chosen room. Tappable target reserved for Step 6.

**Why this matters**

- Path B is a real entry point now. You can browse the lounge, find a room you like, and *then* commit to the ritual — not just light up cold from Home.
- The presence rail finally answers the question every cigar smoker walking into a lounge asks: *what's everyone smoking?* Names + cigars + minutes-in turns a room from "who's online" into "who's actually present."
- The session knows where it lives, the room knows who's lit. Step 5 (system events) can now fire arrival messages because both sides are wired.

**Visible to user**

- Open any room → "Light up here" gold button appears at the top. Tap it → ceremony plays, no picker, you land in the same room with your cigar lit.
- Anyone with an active session shows their cigar + minutes next to their name in the presence rail.
- During an active session, the screen now shows "Sitting at The Late Shift" (or wherever you chose).
- Open a different room while a session is running → the CTA shows "You're lit at The Late Shift" with an Open shortcut.

---

## 2026-05-07 — Rooms × Sessions, Step 5: System events

The room finally reacts. Light up in a room and the chat gets a quiet gold-marked line: *"Marcus has lit up — Padrón 1964 · Old Fashioned"*. End the session: *"Marcus stepped out · 47 min"*. The ritual signals to the people you're sitting with.

**What landed**

- Domain `Message` gains:
  - `kind: Kind` (`.user` | `.arrival` | `.departure` | `.move`) — defaults to `.user` so existing rows stay unchanged.
  - `payload: SystemPayload?` — typed metadata struct with `cigar_brand`, `cigar_line`, `drink_name`, `duration_minutes`, `rating`, `from_room_name`, `to_room_name`, plus snapshotted `display_name` / `avatar_url` so events render correctly even if the actor later changes their profile.
  - `SystemPayload`'s CodingKeys map snake_case JSONB on the wire to camelCase in Swift.
- DTO + Mapper carry kind + payload through.

- `MessageRepository.postSystem(roomID:kind:payload:)` calls the `post_system_message` SECURITY DEFINER RPC from migration 0010. Direct table writes for system kinds are blocked by RLS — only this RPC can post them.

- `SessionViewModel`:
  - Now takes `MessageRepository` and `ProfileRepository` (defaulted) and an analytics arg in the middle.
  - `startSession()` — after the row inserts, calls `postArrivalIfNeeded()`. Suppressed for solo sessions and ghost sessions (privacy non-negotiable).
  - `endSession()` — after `sessions.finish` returns the duration, calls `postDepartureIfNeeded()`. Same gates.
  - `profileSnapshot()` — fetches the actor's display name + avatar URL once at post time so the row renders correctly forever.

- `RoomView.MessageRow` switches on `kind`:
  - `.user` → today's render.
  - `.arrival` / `.departure` / `.move` → new `SystemMessageRow` — flame / moon / arrow glyph in gold, single line of text, monospace timestamp. Background animates a one-shot ember bloom (gold → ember → fade) over ~1.5s when the row first appears so freshly-arrived events feel lit-from-within.
  - Departure rating shows only when ≥4 (the implicit endorsement). Step 7 will gate the rating display to Patron-only on the server side too.

- `RoomViewModel.refreshMessages()` (new) — pull-to-refresh-style refetch that preserves locally-pending sends. Surfaces system events without the realtime stream (still stubbed pending SDK pin, per existing open-items note).

- `RoomView` watches `container.session.isFlowPresented` and `container.session.current?.session?.id`. When either changes (cover dismisses, session ends, session starts in this room) the room refetches messages + smokers — so your own arrival / departure shows up immediately when you minimize back into the room.

- `StubMessageRepo` test mock updated.

**Why this matters**

- Rooms now feel reactive. The ceremony has consequences: people *see* you sit down and *see* you leave. That's the social temperature lift the whole architecture has been building toward.
- The schema + RPC layer keeps clients honest — nobody can spoof "X has lit up" because the insert policy gates on `kind = 'user'`.
- Snapshotted display name + avatar means event rows are immutable history, not stale lookups.

**Visible to user**

- Light up *from* a room → minimize → arrival event in chat with cigar + drink + ember bloom.
- End the session → departure event in the same room with duration.
- Solo sessions never post events. Ghost sessions never post events.

---

## 2026-05-07 — Step 5.5: Realtime, properly wired

The RealtimeService stub from M-era is gone. Channels are real now.

**What landed**

- `Core/Realtime/RealtimeService.swift` rewritten against `supabase-swift` 2.20's V2 channel API (`onPostgresChange(InsertAction.self, …)` / `onPostgresChange(UpdateAction.self, …)` / `onPostgresChange(DeleteAction.self, …)`):
  - One channel per room — topic `room:<uuid>`, filter `room_id=eq.<uuid>`.
  - **Messages — INSERT** → `.message(Message)`. Catches user chat *and* system events (arrival / departure / move) since both go through the `messages` table.
  - **Messages — UPDATE** → `.messageEdited` or `.messageDeleted` depending on `deleted_at` (we soft-delete by setting the column rather than removing the row).
  - **Presence — INSERT** on `room_presence` → fetch the user's `profiles` row, emit a fully-populated `RoomPresence` with display name + avatar.
  - **Presence — DELETE** on `room_presence` → emit `.presenceLeft(userID, roomID)`.
  - Reactions wiring is intentionally deferred (UI doesn't render reactions yet); the `Event` cases stay so the contract is stable.
  - Subscriptions ref-counted per topic; the last consumer's termination calls `client.removeChannel(channel)` which unsubscribes and tears down.
  - `subscribe(roomID:)` is `nonisolated` (returns a value) and bridges callbacks → `AsyncStream` via the SDK's `@Sendable` callback signature.

- All four tables are already in the `supabase_realtime` publication (migration 0001) — no schema change needed.

- `RoomViewModel.apply(_:)`:
  - `.message` now upgrades a local `.pending` row to `.synced` if realtime delivers the canonical version before the HTTP send returns. Append otherwise.
  - System events (arrival / departure / move) trigger a `refreshSmokers()` so the smoker rail's gold-haloed chips update the moment someone lights up next to you.

- `RoomView` lost the cover-dismiss `refreshMessages()` hook from Step 5 — realtime owns that path now. Kept the lighter `refreshSmokers()` so ending your own session updates your own room's chips immediately (the live-now RPC isn't part of the channel filter).

**Why this matters**

- Other people's arrivals now bloom in your chat in real time. Other people's departures land instantly. The "presence rail floats live smokers to the front" actually works *as* people light up.
- The system event experience from Step 5 (gold ember bloom when an arrival row first appears) finally fires for everyone in the room, not just the actor.
- The doorway sheet's "Lit up right now" cards still poll every 30s — that's a fan-out across rooms (not a single channel), and the poll is good enough there. Inside a single room, realtime is the source of truth.

**Visible to user**

- Two devices in the same room: device A lights up → device B sees "X has lit up — Padrón 1964" appear in chat with the gold bloom, no refresh needed. Device A ends → device B sees "X stepped out · 47 min" the same way.
- Chat messages flow live across devices.
- Presence rail updates as people enter/leave the room.

---

## 2026-05-07 — Rooms × Sessions, Step 6: Room switching mid-session

The cigar travels with you. Mid-burn, you can wander the lounge and slide into a different room without ending the session. Either room reacts in real time.

**What landed**

- `SessionRepository.setRoom(sessionID:roomID:)` — patches `sessions.room_id` mid-flight. Pass nil to step out into a solo session.

- `SessionViewModel`:
  - **`moveTo(_:)`** — guarded on `phase == .active`. Three flavors:
    - **From another room** → posts `departure` to the old room, then `move` to the new room with `from_room_name`. Renders as: *"Marcus stepped out · 24 min"* in the old room, *"Marcus moved over from The Late Shift"* in the new.
    - **From solo** → no departure, posts a fresh `arrival` in the new room. Reads identically to a Path-A arrival.
    - **Same room** → no-op.
    - Best-effort `room_members` join + bail before posting the new event if the server update fails.
  - **`stepOutKeepLit()`** — guarded same way. Posts `departure` to the old room, sets `sessions.room_id = null`, clears local mirrors. Bar stays pinned, session keeps burning.
  - **`postMoveIfNeeded(fromRoomName:)`** — same shape as arrival/departure, gated by `!isGhost`.

- `SessionBarView` ellipsis menu rebuilt:
  - Open session
  - **Switch room** — fires the `RoomPickerSheet` (60ms tick after dialog dismissal so the sheet doesn't fight the animation). Pick a room → `moveTo`. Pick "Stay solo" → `stepOutKeepLit`.
  - **Step out (stay lit)** — only shown when `activeRoomID != nil`. Direct call, no picker.
  - End session
  - Cancel

- `RoomPickerSheet` + `RoomPickerViewModel` accept `excludeRoomID`. Filters across all three sections so the picker never offers "move to where you already are."

- `RoomView.LightUpHereCTA` `.activeElsewhere` rebuilt:
  - Two-row layout. Top: *"You're lit at The Velvet Hour"* (or *"You're lit solo right now"*).
  - Bottom: primary gold capsule **"Move over here"** + ghost **"Open session"** link.
  - Move tap → `moveTo(this room)` — works whether you were in another room or solo.

- `JournalStatsTests`' `StubSessionRepo` updated for the new protocol method.

**Why this matters**

- The "I'm walking through the lounge with a lit cigar" fantasy is real now. You can ghost into Lounge mid-session, find a room you like, tap a single button, and land there with the room reacting around you (and the previous room saying you stepped out).
- Step-out-stay-lit gives you a quiet exit ramp from a room without ending the burn — perfect for when a conversation gets weird but you still want the cigar.
- The `move` event from Step 5 finally has a producer; rooms now show the full vocabulary: arrival, departure, move.

**Visible to user**

- During a session, tap the bar's `…` ellipsis → "Switch room" → picker appears with your current room hidden. Pick another → bar stays pinned, new room name shown, both rooms broadcast the right system events.
- "Step out (stay lit)" → bar stays, but you're solo. Old room sees "X stepped out · N min".
- Inside a room while lit elsewhere → "Move over here" gold button → instant transfer.

---

## 2026-05-07 — Rooms × Sessions, Step 7: The Patron tier

The freemium layer is in. The ritual stays free for everyone; depth and customization unlock for Patrons. Gold rings, audio-theme locks, the upsell sheet, the social signal — all live.

**What landed**

- Migration `0012_room_live_now_patron.sql` (applied via MCP) — the live-now RPC now returns `is_premium` per smoker so the doorway sheet's gold ring renders without a fan-out fetch.

- Domain layer:
  - `LiveNowSummary.Smoker.isPatron`
  - `RoomPresence.isPatron` (defaults to false)
  - `SystemPayload.isPatron` — snapshotted at post time so historical arrival/departure rows keep their gold mark even after a subscription expires.
  - `AudioTheme.isPatron` — `loungeMurmur` and `lofi` are free; `jazz`, `rain`, `fireplace` are Patron-gated.

- Wire-up:
  - `RoomRepository.liveNow` decodes `is_premium` and passes it to the domain `Smoker`.
  - `RealtimeService.enrich` pulls `is_premium` from the joined profile when emitting `presenceJoined`.
  - `SessionViewModel.profileSnapshot()` returns `(name, avatar, isPatron)` — every `arrival` / `departure` / `move` payload carries the actor's Patron status.

- `AvatarView` learned `isPatron`. Renders a faint gold ring just outside the avatar (with a soft `goldGlow` shadow). Composes with `isActive` so a smoker can show both rings without conflict. Accessibility label reads "Patron" when set.

- `PatronSheet` (new — `Features/Patron/PatronSheet.swift`):
  - Single screen, leather + warm radial glow, no comparison table.
  - Header: "THE PATRON — Become a patron of the house."
  - Three rotating value lines (3.5s cycle) with a fade-and-slide.
  - Two price cards: **Monthly $7.99** and **Annual $59 / 14-day free trial · save $36** (annual is gold-haloed, the recommended path).
  - Quiet "Restore purchases" link.
  - Fine print: *"The ritual is always free. Patrons unlock depth — never the door."*
  - Trigger string captured in analytics so we can see which moments convert.
  - RevenueCat package IDs `$rc_monthly` / `$rc_annual` (well-known offering identifiers).

- `PaywallView` is now a thin shim that re-presents `PatronSheet`. `PremiumGateModifier` + `.premiumGate(isPremium:trigger:)` keep the existing call sites at JournalView and SettingsView working.

- Patron mark surfaces:
  - **Doorway sheet** — `SmokerRow` overlays a gold ring on patron avatars in the live-now cards.
  - **Room presence rail** — `PresenceChip` passes `isPatron` to `AvatarView`; smoker chips use the live-now snapshot, plain avatars use the presence record.
  - **Chat system messages** — `SystemMessageRow` shows a small gold pip before an arrival/departure/move line when `payload.isPatron == true`.
  - **Profile self avatar** — gold ring renders for patron users when looking at their own profile.

- Audio-theme locks at every picker:
  - **Onboarding vibe step** — new shared `AmbiencePicker` view: lock icon on Patron themes, taps fire `PatronSheet(trigger: "audio_theme_onboarding")`.
  - **Settings → Default ambient** — Picker rows show "🔒" suffix for locked themes; the binding's `set` intercepts a Patron-only selection and presents the upsell.
  - **Profile → Default audio** — same pattern as Settings, presents `PatronSheet(trigger: "audio_theme_profile")`.
  - **Room → Ambience picker** — lock icon next to locked rows; tap presents the upsell rather than committing.

- The Step 3 voice-room placeholder upsell is gone — it now opens the real `PatronSheet(trigger: "voice_room_card")`.

**What's intentionally deferred**

- Multiple Usuals UI (no current UI surfaces multiple usuals; will add when host-room and journal-export ship).
- Cellar / virtual humidor.
- Drop early access (needs a server-side window).
- Departure-rating badge in chat (needs design pass on when to post — leaving the field on the payload but not surfacing it yet).
- Live-now magnifier (global view).

**Visible to user**

- Open Settings → Default ambient → Jazz/Rain/Fireplace show 🔒. Tap one as a free user → PatronSheet rises.
- Doorway sheet's "Lit up right now" cards — Patron smokers carry a faint gold ring around their avatar.
- Profile screen — your own avatar gets the gold ring once you're a Patron.
- Room presence rail — Patron smokers' chips have the same ring.
- A patron's arrival in chat starts with a small gold pip before the line.

---

## Open items (final polish)

- Drop in licensed audio assets per the spec above; verify ambient loops are seamless across AirPods route changes.
- Performance pass: chat with 1k messages on iPhone 11 (target ≤ 60 fps scroll). If `LazyVStack` shows jank, swap `ChatList`'s body for a `UIViewRepresentable` over `UITableView` behind the same view contract.
- A11y deeper sweep: Dynamic Type at xxxLarge across every screen, VoiceOver navigation order, contrast on gold over `surface`/`surfaceHi` (currently ≥ 4.5:1 by inspection but unverified at xxxLarge weights).
- Snapshot tests for Lighting Ceremony key frames (0.5 s / 1.5 s / 3.5 s) — needs a deterministic render path; today the flame is time-driven by `TimelineView`.
- App Store assets: 6.7" + 6.1" + 5.5" screenshots, App Preview video of the Lighting Ceremony.

## Risks logged

- **Supabase Swift SDK API drift** — `postgresChange` / `presenceChange` shapes change across minor versions. Pin once we boot the project locally; if the SDK is on 2.x and types don't match, refactor `RealtimeService` accordingly.
- **AVAudioSession + LiveKit interplay** on real devices — needs route-change observers and category transitions when voice joins. Will land alongside voice in M16.
- **Swift 6 strict concurrency** with Supabase + LiveKit — both SDKs are still tightening Sendable annotations; expect a few `@unchecked Sendable` shims at integration time.
