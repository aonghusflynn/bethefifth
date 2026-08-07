# BeTheFifth — CLAUDE.md

## Project Overview

**BeTheFifth** is a two-sided platform for five-a-side football.

- **Solo players** find and join open games near them
- **Organisers** create games, manage rosters, and fill their squad

Many organisers already have a pitch booked for a term — they just need players. The platform solves that problem for free first, with payment collection as a paid upgrade later.

Initial market: Dublin, Ireland. Expansion planned to UK (Manchester/London) then EU (Amsterdam, Berlin).

### Monetisation Model

| Tier | Price | Features |
|---|---|---|
| **Free** | €0 forever | Post games, manage roster, waitlist, notifications, player profiles |
| **Pro** | €9–12/month or 10% per booking | + Payment collection, recurring games, private games, priority listing |

**Phase 1 launches Free tier only.** Payment processing is a Phase 2 feature unlocked once organisers are active and asking for it.

---

## Stack

| Layer | Technology |
|---|---|
| Mobile + Web | Flutter (Dart) |
| Backend API | Python 3.12 + FastAPI |
| Database | PostgreSQL |
| ORM | SQLAlchemy (async) with Alembic for migrations |
| Auth | Firebase Authentication (Google + Apple login, phone verification) |
| Payments | Stripe Connect (Phase 2 only — not in MVP) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Maps | Google Maps Flutter plugin |
| Hosting | Fly.io (EU region, `lhr` or `ams`) |
| Storage | Supabase Storage (profile photos, venue images) |

---

## Project Structure

```
bethefifth/
├── api/                        # FastAPI backend
│   ├── main.py                 # App entry point
│   ├── config.py               # Settings via pydantic-settings
│   ├── database.py             # Async SQLAlchemy engine + session
│   ├── models/                 # SQLAlchemy ORM models
│   │   ├── user.py
│   │   ├── game.py
│   │   ├── venue.py
│   │   ├── booking.py
│   │   └── notification.py
│   ├── schemas/                # Pydantic request/response schemas
│   │   ├── user.py
│   │   ├── game.py
│   │   ├── venue.py
│   │   └── booking.py
│   ├── routers/                # FastAPI routers (one per domain)
│   │   ├── auth.py
│   │   ├── games.py
│   │   ├── venues.py
│   │   ├── bookings.py
│   │   └── users.py
│   ├── services/               # Business logic layer
│   │   ├── firebase.py         # Firebase Admin SDK wrapper
│   │   ├── notifications.py    # FCM push notification service
│   │   └── geo.py              # Location/radius query helpers
│   ├── middleware/
│   │   └── auth.py             # Firebase JWT verification
│   ├── alembic/                # DB migrations
│   └── tests/
├── app/                        # Flutter frontend
│   ├── lib/
│   │   ├── main.dart
│   │   ├── firebase_options.dart
│   │   ├── core/
│   │   │   ├── constants.dart
│   │   │   ├── router.dart     # go_router navigation
│   │   │   └── theme.dart
│   │   ├── models/             # Dart data models
│   │   ├── providers/          # Riverpod state management
│   │   ├── services/
│   │   │   ├── api_service.dart    # HTTP client (Dio)
│   │   │   └── auth_service.dart   # Firebase Auth
│   │   └── screens/
│   │       ├── auth/
│   │       ├── games/
│   │       ├── organiser/
│   │       └── profile/
│   └── pubspec.yaml
├── docker-compose.yml          # Local dev (postgres + api)
├── fly.toml                    # Fly.io deployment config
└── README.md
```

---

## Core Data Models

### User
```
id, firebase_uid, email, display_name, avatar_url,
phone, position (GK/DEF/MID/ATK), skill_level (1-5),
reliability_score, is_organiser, plan (free|pro), created_at
```

### Venue
```
id, name, address, city, country, lat, lng,
surface (astro/grass/indoor), pitch_size (5/7/11),
parking, notes, created_by, verified
```

### Game
```
id, organiser_id, venue_id, title, description,
starts_at, duration_minutes, max_players, current_players,
skill_level (1-5), cost_per_player (cents, nullable),
currency (EUR/GBP, nullable), free_to_join (boolean),
status (open/full/cancelled/completed),
is_recurring, recurrence_rule (rrule string),
is_private, created_at
```
Note: `cost_per_player` and `currency` are nullable — only set for Pro organiser games with payment enabled.

### Booking
```
id, game_id, player_id, status (confirmed/waitlisted/cancelled),
cancelled_at, created_at
```
Note: No payment fields in Phase 1. Payment fields added in Phase 2 migration.

---

## API Conventions

- All endpoints prefixed `/api/v1/`
- Auth: Firebase JWT in `Authorization: Bearer <token>` header
- All monetary values in **cents/pence** (integers), never floats
- Timestamps in **ISO 8601 UTC**
- Pagination: `?page=1&per_page=20`
- Errors follow RFC 7807 problem+json format

### Key Endpoints

```
GET    /api/v1/games?lat=&lng=&radius_km=&date=&skill=
GET    /api/v1/games/{id}
POST   /api/v1/games                    # organiser only
PATCH  /api/v1/games/{id}
DELETE /api/v1/games/{id}              # cancels game, notifies players

POST   /api/v1/games/{id}/bookings     # join a game (free)
DELETE /api/v1/bookings/{id}           # cancel booking

GET    /api/v1/venues
POST   /api/v1/venues
GET    /api/v1/venues/{id}

GET    /api/v1/users/me
PATCH  /api/v1/users/me
GET    /api/v1/users/{id}/games        # games played/organised

# Phase 2 (not in MVP):
# POST /api/v1/payments/intent
# POST /api/v1/payments/webhook
# POST /api/v1/payments/onboard
```

---

## Business Rules

### Phase 1 — Free Tier Rules
- All games are free to join — no payment required
- Organiser cancellation → all confirmed players notified immediately via push
- Player cancellation → slot opens, first waitlisted player auto-promoted + notified
- Organiser sets game to open/closed manually or it auto-closes when full

### Games
- Game moves to `full` status when `current_players == max_players`
- Waitlist is FIFO — auto-promote when a confirmed player cancels
- Recurring games use rrule; API auto-creates next instance on completion
- Private games require organiser to share a join link/code

### Skill Levels
```
1 = Beginner
2 = Casual
3 = Intermediate
4 = Competitive
5 = Elite
```

---

## Auth Flow

1. Flutter app authenticates via Firebase (Google/Apple/Phone)
2. Firebase returns JWT `idToken`
3. All API calls send `Authorization: Bearer <idToken>`
4. FastAPI middleware verifies token with Firebase Admin SDK
5. `firebase_uid` used to look up/create user in PostgreSQL
6. Never store passwords — Firebase handles all credentials

---

## Flutter State Management

Use **Riverpod** (flutter_riverpod + riverpod_annotation).

Key providers:
- `authProvider` — current Firebase user state
- `gamesProvider` — paginated game list with filters
- `gameDetailProvider(id)` — single game + booking state
- `userProvider` — current user profile

Use `AsyncNotifier` for all server-backed state. No direct API calls from widgets.

---

## Flutter Key Packages

```yaml
dependencies:
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x
  go_router: ^13.x
  dio: ^5.x                    # HTTP client
  firebase_core: ^2.x
  firebase_auth: ^4.x
  firebase_messaging: ^14.x
  google_maps_flutter: ^2.x
  intl: ^0.19.x                # date formatting
  cached_network_image: ^3.x
  geolocator: ^11.x
  # Phase 2: flutter_stripe: ^10.x
```

---

## Environment Variables (API)

```
DATABASE_URL=postgresql+asyncpg://...
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=  # base64 encoded
ALLOWED_ORIGINS=https://bethefifth.com,http://localhost:3000

# Phase 2 only:
# STRIPE_SECRET_KEY=
# STRIPE_WEBHOOK_SECRET=
# STRIPE_PLATFORM_FEE_PERCENT=10
```

---

## Local Development

```bash
# Start postgres locally
docker-compose up -d

# Backend
cd api
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn main:app --reload --port 8000

# Flutter
cd app
flutter pub get
flutter run
```

API docs auto-available at `http://localhost:8000/docs`

---

## Multi-Currency (Phase 2)

- Store all amounts as integers (cents/pence) — never floats
- `currency` field on Game and Booking (`EUR` or `GBP`)
- Dublin launch = EUR only; UK launch adds GBP — no schema changes needed
- Stripe handles FX; never convert currencies in application code
- Schema already supports this via nullable `cost_per_player` + `currency` fields on Game

---

## Geo Queries

Games are queried by proximity. PostgreSQL with PostGIS extension preferred, or use the Haversine formula with a bounding box pre-filter:

```sql
SELECT * FROM games
WHERE lat BETWEEN :min_lat AND :max_lat
AND lng BETWEEN :min_lng AND :max_lng
AND status = 'open'
AND starts_at > NOW()
ORDER BY starts_at ASC;
```

Add PostGIS `geography` column for accurate radius queries at scale.

---

## SEO Note

Flutter web has limited SEO capability. Public game discovery pages (`/games/dublin`, individual game pages) should be server-rendered. Consider a lightweight Next.js or FastAPI + Jinja2 public web layer for SEO surfaces once MVP is validated. Not needed for Phase 1.

---

## Phase 1 — Dublin MVP Scope

**In scope:**
- Player registration + profile
- Browse + join games for free (map + list)
- Create + manage games (organiser)
- Roster management + waitlist (no payments)
- Push notifications (game reminders, roster changes)
- Dublin venue directory (pre-seeded)

**Explicitly out of scope for MVP:**
- Payment collection (Phase 2)
- Recurring games (Phase 2)
- Leagues / standings
- Venue partner portal
- Player reputation/ratings
- In-app chat
- UK/EU expansion

## Phase 2 — Monetisation

Triggered when organisers are active and requesting payment features.

- Stripe Connect onboarding for organisers
- Payment collection on booking
- Refund logic (cancellation rules)
- Pro organiser subscription (€9–12/month)
- Recurring game automation
- Private games with join codes

---

## Owner

Aonghus — Dublin, Ireland  
Stack preference: Python backend, Flutter mobile  
Contact: define before going to production
