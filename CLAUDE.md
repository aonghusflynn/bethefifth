# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BeTheFifth** is a two-sided platform for five-a-side football. Solo players find and join open games near them; organisers create games, manage rosters, and fill their squad. Many organisers already have a pitch booked — they just need players.

Initial market: Dublin, Ireland. Expansion planned to UK then EU (France, Netherlands, Spain, Italy, Germany).

### Monetisation

| Tier | Price | Features |
|---|---|---|
| **Free** | €0 forever | Post games, manage roster, waitlist, notifications, player profiles |
| **Pro** | €9–12/month or 10% per booking | + Payment collection, recurring games, private games, priority listing |

**Phase 1 launches Free tier only.** Payment processing is Phase 2.

## Domain Model

- **Game** — a recurring time + location definition (e.g. "Tuesdays 7pm at Irishtown Stadium")
- **Match** — a single instance of a game on a specific date
- **Squad** — an organiser's persistent pool of regular players. Deliberately allowed to be larger than a game's `max_players`: every member is invited to each match and slots fill first-come-first-served from whoever accepts. Members without an account yet exist as `invited` rows carrying a name + email, and are linked to a real user on registration
- **Venue** — pitch location with surface type, size, coordinates
- **Booking** — a player's confirmed/waitlisted/cancelled slot in a game
- **Organiser** — creates games, manages teams/rosters, approves join requests, rates players
- **Player** — gets assigned to games, responds to match notifications, can request to join open matches

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile + Web | Flutter (Dart) |
| Backend API | Python 3.12 + FastAPI |
| Database | PostgreSQL |
| ORM | SQLAlchemy (async) + Alembic migrations |
| Auth | Firebase Authentication (Google + Apple + Phone) |
| Push Notifications | Firebase Cloud Messaging |
| Maps | Google Maps Flutter plugin |
| Hosting | Fly.io (EU region) |
| Storage | Supabase Storage (profile photos, venue images) |
| Transactional email | Resend (squad invites to unregistered players) |
| Payments | Stripe Connect (Phase 2 only) |

## Development Commands

```bash
# Local infra
docker-compose up -d                          # Start postgres

# Backend
cd api
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head                          # Run migrations
uvicorn main:app --reload --port 8000         # Start API server
# API docs: http://localhost:8000/docs

# Frontend
cd app
flutter pub get
flutter run
```

## Architecture

### Backend (`api/`)

Layered: **routers → services → models/schemas → database**

- `routers/` — FastAPI route handlers, one per domain (auth, games, venues, bookings, users)
- `services/` — Business logic (firebase.py, notifications.py, geo.py)
- `models/` — SQLAlchemy ORM models (User, Game, Venue, Booking, Notification)
- `schemas/` — Pydantic request/response schemas
- `middleware/auth.py` — Firebase JWT verification
- `config.py` — Settings via pydantic-settings
- `database.py` — Async SQLAlchemy engine + session

### Frontend (`app/lib/`)

- `providers/` — Riverpod providers. Use `AsyncNotifier` for all server-backed state. No direct API calls from widgets.
- `services/` — API client (Dio) and Firebase Auth wrapper
- `screens/` — UI by domain (auth, games, organiser, profile)
- `core/` — Constants, go_router config, theme
- `models/` — Dart data models

### Auth Flow

1. Flutter authenticates via Firebase (Google/Apple/Phone) → gets JWT `idToken`
2. All API calls send `Authorization: Bearer <idToken>`
3. FastAPI middleware verifies with Firebase Admin SDK
4. `firebase_uid` used to look up/create user in PostgreSQL

## API Conventions

- All endpoints prefixed `/api/v1/`
- Monetary values in **cents/pence** (integers, never floats)
- Timestamps in **ISO 8601 UTC**
- Pagination: `?page=1&per_page=20`
- Errors: RFC 7807 problem+json format

## Business Rules

- Game auto-moves to `full` status when `current_players == max_players`
- Waitlist is FIFO — auto-promote first waitlisted player when a confirmed player cancels
- Organiser cancellation → all confirmed players notified via push
- Player cancellation → slot opens, waitlist promotion + notification
- Recurring games use rrule; API auto-creates next instance on completion
- Private games require organiser to share a join link/code
- Geo queries use Haversine with bounding-box pre-filter (PostGIS planned for scale)
- Skill levels: 1=Beginner, 2=Casual, 3=Intermediate, 4=Competitive, 5=Elite
- Ratings are two-way: organisers rate players (skill, punctuality, soundness); players rate matches (game quality, venue, organisation)

## Key Workflows

### Organiser
1. Creates a game (time, location, optional recurrence) and a team
2. Assigns players to a game; system creates matches and notifies players
3. If short on players, opens the match for outside requests
4. Accepts/rejects requesting players
5. Rates players on: skill level, punctuality, "soundness"

### Player
1. Browses open matches nearby (location-based discovery via map + list)
2. Views match details (time, venue, skill level) and joins
3. Receives match notifications and responds (accept/decline)
4. After playing, rates the match (game quality, venue, organisation)

## Phase Boundaries

**Phase 1 (Dublin MVP):** Free games only, player registration + profiles, browse/join games (map + list), roster management + waitlist, push notifications, pre-seeded Dublin venue directory, squads with email invites, recurring games, per-instance attendance requests, marketplace spillover. No payment fields, no Stripe.

**Phase 2:** Stripe Connect onboarding, payment collection on booking, refund logic, Pro subscription, private games with join codes. `cost_per_player` and `currency` fields on Game are nullable — only populated in Phase 2.

## Design System

Design assets live in `design files/`. When building UI, always use the established brand tokens — don't improvise colors, fonts, or spacing.

- **`app/lib/core/theme.dart`** — Flutter `ThemeData` implementation (copy into `app/` when scaffolding). Use `BtfTheme.light()` / `BtfTheme.dark()` with `ThemeMode.system`.
- **`Brand Guide.html`** — Full brand identity: color palette, typography, logo usage
- **`App Theme Reference.html`** — Visual reference for app screens (light/dark mode mockups)
- **`Logo Package.html`** — Logo variants and usage rules
- **`Landing Page.html`** — Marketing landing page design
- **`Pitch Deck.html`** / **`Pitch Deck-print.html`** — Investor deck (web + print versions)

### Brand Tokens

| Token | Value | Usage |
|---|---|---|
| Pitch Lime | `#D5F24A` | Primary accent, CTAs, success |
| Match Night (ink) | `#0B0D0C` | Text, dark backgrounds |
| Chalk Line (paper) | `#F6F5F1` | Light backgrounds |
| Stoppage (coral) | `#E66849` | Alerts, errors, danger |
| Floodlight (blue) | `#4A9EE0` | Links, night mode accents |

### Typography

- **Space Grotesk** — Display/headlines (tight tracking, heavy weight)
- **Inter** — Body text
- **JetBrains Mono** — Timestamps, scores, data values (`BtfText.mono()`)

### Spacing & Radius

Use `BtfSpace` (4–64px scale) and `BtfRadius` (6–100px). Buttons use `StadiumBorder` (pill shape). Cards use `BtfRadius.md` (14px).

## Internationalisation (i18n)

Supported locales: `en`, `fr`, `nl`, `es`, `it`, `de`

**Frontend:**
- Use Flutter `flutter_localizations` + `intl` package with ARB files
- Never hardcode user-facing strings — always use `AppLocalizations.of(context).someKey`
- Dates/times displayed in user's locale via `intl`

**Backend:**
- User model stores `locale` preference
- All user-facing strings (error messages, push notifications, emails) go through a translation layer
- Push notifications sent in the user's preferred locale

## Development Principles

- **SOLID principles** — single responsibility for services, dependency injection for testability (FastAPI `Depends()`, Riverpod providers), interface segregation between layers
- **TDD for business logic** — write tests first for backend services (waitlist promotion, booking rules, ratings, geo queries). Flutter: TDD for providers/services; widget tests can follow once UI stabilises.
- **Pragmatic layering** — follow the spirit of clean architecture (dependency direction flows inward, separation of concerns) without ceremonial abstractions. Don't add repository interfaces or abstract classes until there's a concrete reason (e.g. swapping a data source).

## Environment Variables (API)

```
DATABASE_URL=postgresql+asyncpg://...
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=  # base64 encoded
ALLOWED_ORIGINS=https://bethefifth.com,http://localhost:3000
RESEND_API_KEY=              # unset in dev — EmailService logs instead of sending
EMAIL_FROM=BeTheFifth <noreply@bethefifth.com>
APP_BASE_URL=http://localhost:5173
```
