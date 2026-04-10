# Cross Cribbage

A real-time multiplayer twist on cribbage. Two players take turns placing cards on a 5×5 grid, scoring hands across rows and columns. First to 31 pegging points wins. Supports human vs. human and human vs. computer.

## How it works

Each round, a starter card fills the center cell. Players each receive 14 cards and must discard 2 to the crib before placing. Cards are placed one per turn onto the 5×5 board.

- **Player 1** scores columns; **Player 2** scores rows.
- Hands are scored using standard cribbage rules (fifteens, pairs, runs, flush, nobs).
- The round point diff is awarded to the winner; first to 31 cumulative points wins.
- No accounts — identity is a token stored in `localStorage`. Share a game link to invite a second player.

## Architecture

**Backend** — Rails 8 + PostgreSQL. All game state lives in a single `games` table (UUID PK, JSONB for card data). ActionCable pushes state to clients after every mutation. Background jobs handle AI moves (`ComputerMoveJob`) and round auto-advance (`AdvanceRoundJob`).

**Frontend** — React 19 + TypeScript + Vite, served separately. React Query manages server state; `useGameChannel` merges ActionCable pushes directly into the query cache for real-time updates.

Key files:
- `app/models/game.rb` — all game logic
- `app/lib/cribbage_hand.rb` — hand scoring
- `app/lib/computer_player.rb` — AI decisions
- `app/channels/game_channel.rb` — ActionCable
- `app/frontend/` — React app

## Running with Docker

Copy the example env file (defaults work out of the box for local development):

```bash
cp .env.example .env
```

Then start all services (Postgres, Rails, Vite):

```bash
docker compose up --build
```

- Rails API: http://localhost:3000
- Vite dev server: http://localhost:3036

The `web` container runs `db:prepare` on startup, so no separate migration step is needed.

## Running locally (without Docker)

```bash
bin/rails s -p 3000   # Rails API on :3000
bin/vite dev          # Vite dev server (separate terminal)
```

Or use foreman to run both at once:

```bash
foreman start -f Procfile.dev
```

## Tests

```bash
bundle exec rspec
```
