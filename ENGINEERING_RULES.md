# Engineering Rules — The Final Third

## Non-Negotiable Standards

- Swift 6 only
- SwiftUI only
- MVVM using @Observable only
- No ObservableObject
- No business logic inside Views
- Repository pattern required
- Feature-based folder structure
- No placeholder code
- No TODO architecture
- No force unwraps
- No blocking main thread

---

## Performance

- Chat must handle long sessions
- Use UITableView wrapper for messages
- Avoid memory growth from chat history
- Paginate messages

---

## Offline

Must support:
- offline journal viewing
- offline session queue
- local cigar cache

---

## Realtime

Must handle:
- reconnects
- dropped websocket
- duplicate events safely

---

## Security

- Supabase anon key only client-side
- service role never exposed
- RLS required

---

## UI

- Dark mode only
- Gold is semantic
- No light theme
- No bright colors

---

## Testing

Must include:
- auth tests
- repository tests
- session flow tests
- lounge realtime tests