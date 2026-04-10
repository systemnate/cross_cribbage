# Active Games List

Track active games in localStorage so players can rejoin games they accidentally closed, and end waiting games that are blocking new game creation.

## Problem

If a player clicks "Start New Game" and then navigates away (or clicks it again), the server blocks creating a new game because a waiting game already exists for their token. There's no way to get back to that game or delete it.

## Design

### 1. localStorage game list (`storage.ts`)

New storage key `ccg_games` holding a JSON array of game entries:

```ts
type StoredGame = {
  gameId: string;
  vsComputer: boolean;
  createdAt: number; // Date.now()
}
```

New helpers:

- `addGame(gameId: string, vsComputer: boolean)` — append to the list
- `removeGame(gameId: string)` — remove an entry by ID
- `getGames(): StoredGame[]` — return the list, pruning entries older than 2 hours (matches `DestroyGameJob` TTL)

Called from the existing `createGame`, `playComputer`, and `joinGame` mutation `onSuccess` handlers in `HomePage.tsx`.

### 2. Backend: `DELETE /api/games/:id`

New endpoint in `Api::GamesController`:

- Authenticated via `player_token` cookie (existing `set_current_token` flow)
- Only destroys if **both**: caller's token matches `player1_token` AND `status == "waiting"`
- Returns `{ ok: true }` on success
- Returns 422 if game is not in waiting status
- Returns 401 if caller is not the game creator
- Returns 404 if game not found

Route: `delete '/api/games/:id', to: 'api/games#destroy'`

### 3. Frontend API (`api.ts`)

Add:

```ts
deleteGame: (id: string): Promise<{ ok: boolean }> =>
  request("DELETE", `/games/${id}`),
```

### 4. Home page "Your Games" section (`HomePage.tsx`)

Displayed below the create/join buttons when `getGames()` returns a non-empty list.

Each entry shows:
- Truncated game ID (first 8 chars) with "vs Computer" or "vs Human" label
- **Rejoin** link — navigates to `/game/:id`
- **End Game** button — calls `deleteGame`, removes from localStorage on success

Error handling:
- If End Game returns 404: game was already destroyed. Remove from localStorage silently.
- If End Game returns 422: game already started. Remove End Game button, keep Rejoin.
- If Rejoin navigates to a game that 404s on fetch: the `useGame` hook will show an error; the player can return home and the stale entry will be pruned on next `getGames()` call (2-hour TTL handles this, or we can prune on 404 in `GamePage`).

### 5. Visual layout

```
[Start New Game]  [Play Computer]
         ── or ──
[Paste Game ID        ] [Join]

── Your Games ──
abc12345  vs Human     [Rejoin] [End Game]
def67890  vs Computer  [Rejoin]
```

Styled consistently with the existing dark theme (slate/yellow/green palette).

## Files changed

| File | Change |
|------|--------|
| `app/frontend/lib/storage.ts` | Add `StoredGame` type, `addGame`, `removeGame`, `getGames` |
| `app/frontend/lib/api.ts` | Add `deleteGame` method |
| `app/frontend/components/HomePage.tsx` | Add Your Games section, wire up mutations |
| `app/controllers/api/games_controller.rb` | Add `destroy` action |
| `config/routes.rb` | Add DELETE route |

## Testing

- **Request spec**: `DELETE /api/games/:id` — test waiting game destroyed, non-waiting game rejected, unauthorized caller rejected, 404 for missing game
- **Manual**: create game, navigate home, see it listed, rejoin it, end it
