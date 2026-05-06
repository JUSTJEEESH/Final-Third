# The Final Third — Complete Master PRD (v3)

## iOS App Build Instructions (Fully Integrated)

---

# What We Are Building

A premium iOS app called **The Final Third**.

It is a **ritual-based social cigar lounge experience**.

Not a tracker.  
Not a feed.  
A *place*.

A digital third place where someone:
- Gets home
- Pours a drink
- Lights a cigar
- Opens the app
- And their people are already there

An hour passes.

They go to bed better than they arrived.

---

## Core Product Truth

> Users don’t just open this app.  
> They **show up**.

The product must reinforce:
- Habit (The Usual)
- Atmosphere (audio, visuals, pacing)
- Presence (real-time people)
- Emotional payoff (relaxation, connection)

---

# Tech Stack

- Swift 6, SwiftUI
- iOS 17+
- MVVM with `@Observable`
- Supabase (auth, DB, realtime)
- RevenueCat (subscriptions)
- CoreData (offline cache)
- Realtime:
  - Supabase → chat + presence
  - WebRTC (LiveKit/Agora) → voice
- Audio:
  - AVAudioEngine / AVPlayer

---

# Design System (UNCHANGED)

(Use original exactly)

---

# App Structure

```
Home | Explore | Lounge | Journal | Profile
```

Custom tab bar, dark theme only, gold accent system.

---

# CORE SYSTEMS

---

## 1. Authentication System

- Sign in with Apple (primary)
- Email/password (secondary)
- Session persistence
- Profile setup:
  - Name or handle
  - Optional location (self-declared)
  - “Honduras local?” toggle

---

## 2. App Config System

- Supabase `app_config` table
- Cached locally with TTL
- Controls:
  - Copy
  - Featured cigar
  - Events
  - Pairings
  - Drops

---

## 3. Cigar + Drink Data Layer

- Supabase source of truth
- CoreData local cache
- Search:
  - Local first
  - Fallback to Supabase
- Filters:
  - Region
  - Strength
  - Wrapper

---

## 4. The Usual (Daily Ritual System)

### Purpose:
Create a nightly habit loop

### Flow:
- User sets:
  - Time
  - Default cigar
  - Default drink
- Notification:
  > “Your chair is ready.”
- Tap → skips setup → Lighting Ceremony

### Streak System:
- Tracks consecutive sessions
- Visual progression:
  - Ember → Flame → Fire

### Data Model:
```
usuals
- id
- user_id
- preferred_time
- cigar_id
- drink_id
- enabled
- streak_count
- last_completed_at
```

---

## 5. Lounge System (CORE EXPERIENCE)

### Room List:
- Room name, theme, occupants
- Gold highlight if active

### Entry Flow (UPDATED):

### Step 0:
- Use The Usual
- Join quietly (Ghost Mode toggle)

### Step 1:
Select cigar

### Step 2:
Select drink

### Step 3:
Lighting Ceremony

---

## 6. Lighting Ceremony (CRITICAL)

- Full-screen immersive animation
- Lighting methods:
  - Match
  - Torch
  - Cedar spill, etc.

### Behavior:
- Screen dim
- Flame animation
- Ember glow
- Haptic feedback
- Cigar name reveal

---

## 7. Lounge Room Experience

### Presence:
- Avatar rail
- Live updates

### Chat:
- High-performance (UITableView)
- Reactions
- Text only

### NEW ADDITIONS:

### Ambient Audio:
- Lounge murmur
- Jazz / lo-fi
- Rain
- Fireplace

- Toggle inside room
- Remembers preference

### Voice Presence:
- Push-to-talk
- Optional live voice rooms
- Max 4–6 speakers

### Ghost Mode:
- Invisible presence
- No notifications triggered

### Arrival Signal:
- Subtle haptic + banner when connection enters

### Burn Timer:
- Tracks thirds
- Final third:
  - Gold pulse
  - Haptic
  - Banner

---

## 8. Session System

### Start:
- From Lounge or The Usual

### During:
- Burn timer
- Presence tracking

### End (UPDATED):

Session Summary:
- Duration
- Ratings:
  - Flavor
  - Draw
  - Overall
- Would smoke again

### NEW:
- Mood slider
- “Did this help you unwind?”

---

## 9. Journal System

### Features:
- Session history
- Stats dashboard

### Metrics:
- Total smokes
- Favorite cigar
- Preferred strength
- Favorite pairing

### NEW:
- Weekly recap:
  - Sessions per week
  - Avg duration

### Premium Gate:
- Only last 30 sessions free

---

## 10. Social System

### Connections:
- Add / accept

### NEW: Connection Chemistry
- Sessions together
- Time spent together

UI:
> “You and Marcus smoke well together”

---

## 11. Reputation System

### Badges:
- Good Company
- Regular
- Palate Pro

### Based on:
- Time spent
- Engagement
- Session quality

---

## 12. Explore Tab

### Features:
- Search
- Filters
- Cigar library
- Drink library

---

## 13. Cigar Detail

(Use original spec exactly)

---

## 14. Real-World Layer

### Features:
- “Who’s smoking in [city]”
- Events:
  - Create
  - RSVP

### Data:
```
events
- id
- creator_id
- title
- location_name
- city
- datetime
- cigar_id
```

---

## 15. Cigar Drop System

### Features:
- Weekly featured cigar
- Limited-time rooms
- Special pairings

---

## 16. Home Tab (UPDATED)

### Sections:
- Greeting
- Tonight’s Pick
- Active Rooms

### NEW:
- Your Ritual (The Usual)
- Drop of the Week
- Nearby Tonight

---

## 17. Profile Tab (UPDATED)

### Includes:
- Avatar
- Stats
- Connections

### NEW:
- The Usual settings
- Reputation badges
- Weekly stats

---

## 18. Settings

### Includes:
- Account
- Notifications
- Premium

### NEW:
- Audio preferences
- Voice preferences
- Ghost mode default

---

## 19. Subscription System

- RevenueCat
- Paywall triggers:
  - Private rooms
  - Journal history
  - Pairings
  - The Usual advanced features

---

## 20. Offline Strategy

- CoreData:
  - Cigars
  - Sessions
- Queue writes
- Sync on reconnect

---

## 21. Realtime Architecture

- Supabase:
  - Chat
  - Presence
- WebRTC:
  - Voice

---

## 22. Performance Considerations

- Limit voice participants
- Optimize chat rendering
- Pause audio in background

---

# BUILD ORDER

1. Project setup
2. Supabase + config
3. Auth + onboarding
4. Data layer
5. Explore
6. Lounge (base)
7. Session system
8. Lighting ceremony
9. Journal
10. Home
11. Profile + social
12. Paywall
13. Audio + voice
14. Final polish

---

# KEY PRODUCT DETAILS

- Lighting ceremony = emotional anchor
- Final third moment = identity
- Arrival signal = presence
- Gold = meaning, not decoration
- No empty states

---

# FINAL PRINCIPLES

1. This is a place, not a tool  
2. Ritual > features  
3. Atmosphere > speed  
4. Presence > content  

---

# FINAL INSTRUCTION

Build this like:

- A senior iOS engineer  
- A realtime systems architect  
- A product designer obsessed with feeling  

This app must scale to 100,000+ users.

Do not cut corners.

Make it feel like somewhere people return to every night.