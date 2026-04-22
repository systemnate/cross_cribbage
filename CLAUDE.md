# Cross Cribbage

A real-time multiplayer twist on cribbage: two players take turns placing cards on a 5×5 grid, scoring hands across each row and column. First to 31 pegging points wins. Supports both human vs. human and vs. computer play.

## Tech Stack

- **Backend**: Rails 8, PostgreSQL, ActionCable (Solid Cable), Solid Queue (background jobs)
- **Frontend**: React 19, TypeScript, Vite, Tailwind CSS v4, React Query, React Router, `@rails/actioncable`
- **Testing**: RSpec (request and model specs)

## Development

```bash
# Start both servers (Rails on :3000, Vite dev server)
bin/dev

# Or manually
bin/rails s -p 3000
bin/vite dev
```

## Testing

```bash
bundle exec rspec                    # all specs
bundle exec rspec spec/models        # model specs only
bundle exec rspec spec/requests      # request specs only
```

No JavaScript test suite exists currently.

## Architecture

### Backend

**`app/models/game.rb`** — all game state and rules. Key public methods:
- `deal!` — called when player 2 joins; assigns crib, deals cards, starts round
- `place_card!(slot, row, col)` — places the top card from a player's deck onto the board
- `discard_to_crib!(slot)` — discards a card to the crib (2 discards required before placing cards)
- `confirm_scoring!(slot)` / `advance_round!` — scoring phase transitions
- `serialize_for(token)` — builds the per-player JSON payload

**`app/lib/cribbage_hand.rb`** — scores a hand (fifteens, pairs, runs, flush, nobs). Used for rows, columns, and the crib.

**`app/lib/computer_player.rb`** — AI decision logic for vs-computer games.

**`app/channels/game_channel.rb`** — ActionCable channel. Authenticates via `player_token` and streams from `game_{id}`. `GameChannel.broadcast_game_state(game)` is the single broadcast point — called after every mutation.

**`app/controllers/api/games_controller.rb`** — REST API. Token auth via `Authorization: Bearer <token>` header (set in `ApiController`).

**Background jobs:**
- `ComputerMoveJob` / `ComputerConfirmJob` — AI moves, enqueued from `Game#maybe_enqueue_computer_jobs!` after any state change. `ComputerMoveJob` runs immediately; `ComputerConfirmJob` is delayed 1 second so the human's HTTP response reaches the client before the scoring broadcast fires
- `AdvanceRoundJob` — auto-advances round 10 seconds after scoring phase (human vs human only)
- `DestroyGameJob` — destroys game 2 hours after creation

### Frontend (`app/frontend/`)

```
entrypoints/application.tsx   # React root, router
components/
  HomePage.tsx                # Create / join game
  GamePage.tsx                # Main game UI shell
  Board.tsx / BoardCell.tsx   # 5×5 card grid
  PegBoard.tsx                # Score pegging display
  CribArea.tsx                # Crib discard indicator
  CardPreview.tsx             # Card image/display
  ScoringOverlay.tsx          # Scoring phase overlay
hooks/
  useGame.ts                  # React Query fetch for game state
  useGameChannel.ts           # ActionCable subscription, merges server pushes into query cache
  useGameAction.ts            # Wraps API mutations
lib/
  api.ts                      # Typed fetch wrappers for all API endpoints
  cable.ts                    # ActionCable consumer singleton
  storage.ts                  # localStorage helpers (game ID, token)
types/game.ts                 # Shared TypeScript types
```

## Game Rules (implementation notes)

- Board is 5×5; center cell `[2][2]` is pre-filled with the starter card each round.
- Each player gets 14 cards per round; 2 must be discarded to the crib before placing.
- **player1 always scores columns; player2 always scores rows.** Crib score goes to whoever owns the crib that round.
- Scoring: point diff (p1_total − p2_total) is awarded to the winner each round; first to reach 31 wins.
- Nibs: if the starter card is a Jack, the crib owner scores 2 pts immediately.
- vs. computer: `player2` is always the computer. Jobs are enqueued automatically via `maybe_enqueue_computer_jobs!` after each state change.

## API Endpoints

```
POST   /api/games                    # create game; pass vs_computer: true for AI opponent
POST   /api/games/:id/join           # player 2 joins (human vs human)
GET    /api/games/:id                # fetch game state (token-scoped)
POST   /api/games/:id/place_card     # { row:, col: }
POST   /api/games/:id/discard_to_crib
POST   /api/games/:id/confirm_round
```

All write endpoints require `Authorization: Bearer <token>` and return the updated game state (via `serialize_for`).

## Database

Single `games` table with UUID primary key. All card data stored as JSONB arrays. No user accounts — identity is a 32-char hex token stored in the client's localStorage.
