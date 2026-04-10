# Active Games List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players see, rejoin, and end their active games from the home page.

**Architecture:** localStorage stores a list of game entries. A new DELETE endpoint lets players destroy waiting games. The home page renders the list with rejoin links and end-game buttons.

**Tech Stack:** Rails, RSpec, React, TypeScript, React Query, Tailwind CSS

---

### Task 1: Backend — `DELETE /api/games/:id`

**Files:**
- Modify: `config/routes.rb:7` — add `:destroy` to resources
- Modify: `app/controllers/api/games_controller.rb` — add `destroy` action

- [ ] **Step 1: Add route**

In `config/routes.rb`, change:

```ruby
resources :games, only: %i[show create] do
```

to:

```ruby
resources :games, only: %i[show create destroy] do
```

- [ ] **Step 2: Add `destroy` action**

In `app/controllers/api/games_controller.rb`, add `:destroy` to the `set_game` filter but NOT to `GAME_ACTIONS` (which gates on `authorize_player!`), because we need custom auth logic — only player1 can delete, and we want a clear 403 (not 401) for non-creators.

Change the `before_action :set_game` line:

```ruby
before_action :set_game,          only: [:join, :destroy] + GAME_ACTIONS
```

Then add the action after the `confirm_round` method:

```ruby
# DELETE /api/games/:id
def destroy
  unless @game.player1_token == @current_token
    return render_error("Only the game creator can end this game", status: :forbidden)
  end
  unless @game.status == "waiting"
    return render_error("Can only end a game that is waiting for players")
  end

  @game.destroy!
  render json: { ok: true }
end
```

- [ ] **Step 3: Verify route exists**

Run: `bin/rails routes | grep "DELETE.*games"`

Expected output includes: `DELETE /api/games/:id(.:format)  api/games#destroy`

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/api/games_controller.rb
git commit -m "feat: add DELETE /api/games/:id endpoint for ending waiting games"
```

---

### Task 2: Request spec for `DELETE /api/games/:id`

**Files:**
- Modify: `spec/requests/games_spec.rb` — add `describe "DELETE /api/games/:id"` block

- [ ] **Step 1: Write the tests**

Add this block at the end of the outer `RSpec.describe`, before the final `end`:

```ruby
describe "DELETE /api/games/:id" do
  let(:game) { create(:game) }

  it "destroys a waiting game when called by the creator" do
    cookies[:player_token] = game.player1_token
    delete "/api/games/#{game.id}"
    expect(response).to have_http_status(:ok)
    expect(json).to eq("ok" => true)
    expect(Game.exists?(game.id)).to be false
  end

  it "returns 403 when called by someone other than the creator" do
    cookies[:player_token] = "not-the-creator-token"
    delete "/api/games/#{game.id}"
    expect(response).to have_http_status(:forbidden)
    expect(Game.exists?(game.id)).to be true
  end

  it "returns 422 when the game is not in waiting status" do
    active_game = create(:game, :active)
    active_game.deal!
    active_game.reload
    cookies[:player_token] = active_game.player1_token
    delete "/api/games/#{active_game.id}"
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Game.exists?(active_game.id)).to be true
  end

  it "returns 401 without a cookie" do
    delete "/api/games/#{game.id}"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 404 for a non-existent game" do
    cookies[:player_token] = game.player1_token
    delete "/api/games/#{SecureRandom.uuid}"
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `bundle exec rspec spec/requests/games_spec.rb -e "DELETE" -f doc`

Expected: all 5 examples pass.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/games_spec.rb
git commit -m "test: add request specs for DELETE /api/games/:id"
```

---

### Task 3: Frontend — storage helpers

**Files:**
- Modify: `app/frontend/lib/storage.ts` — add `StoredGame` type and helpers

- [ ] **Step 1: Add the game list helpers**

Add the following below the existing exports in `storage.ts`:

```ts
const GAMES_KEY = "ccg_games";
const TWO_HOURS_MS = 2 * 60 * 60 * 1000;

export interface StoredGame {
  gameId: string;
  vsComputer: boolean;
  createdAt: number;
}

export function getGames(): StoredGame[] {
  const raw = localStorage.getItem(GAMES_KEY);
  if (!raw) return [];
  try {
    const games: StoredGame[] = JSON.parse(raw);
    const fresh = games.filter((g) => Date.now() - g.createdAt < TWO_HOURS_MS);
    if (fresh.length !== games.length) {
      localStorage.setItem(GAMES_KEY, JSON.stringify(fresh));
    }
    return fresh;
  } catch {
    localStorage.removeItem(GAMES_KEY);
    return [];
  }
}

export function addGame(gameId: string, vsComputer: boolean): void {
  const games = getGames().filter((g) => g.gameId !== gameId);
  games.push({ gameId, vsComputer, createdAt: Date.now() });
  localStorage.setItem(GAMES_KEY, JSON.stringify(games));
}

export function removeGame(gameId: string): void {
  const games = getGames().filter((g) => g.gameId !== gameId);
  localStorage.setItem(GAMES_KEY, JSON.stringify(games));
}
```

- [ ] **Step 2: Commit**

```bash
git add app/frontend/lib/storage.ts
git commit -m "feat: add localStorage game list helpers"
```

---

### Task 4: Frontend — API helper

**Files:**
- Modify: `app/frontend/lib/api.ts` — add `deleteGame`

- [ ] **Step 1: Add deleteGame**

Add this method to the `api` object in `api.ts`, after `confirmRound`:

```ts
deleteGame: (id: string): Promise<{ ok: boolean }> =>
  request("DELETE", `/games/${id}`),
```

- [ ] **Step 2: Commit**

```bash
git add app/frontend/lib/api.ts
git commit -m "feat: add deleteGame API helper"
```

---

### Task 5: Frontend — Home page "Your Games" section

**Files:**
- Modify: `app/frontend/components/HomePage.tsx` — add game list UI, wire up storage and delete

- [ ] **Step 1: Update imports**

Replace the import line:

```ts
import { setGameId, clearSession } from "../lib/storage";
```

with:

```ts
import { setGameId, clearSession, getGames, addGame, removeGame } from "../lib/storage";
```

- [ ] **Step 2: Wire `addGame` into existing mutations**

In the `createGame` mutation's `onSuccess`, after `setCreatedGameId(game_id)`, add:

```ts
addGame(game_id, false);
```

In the `playComputer` mutation's `onSuccess`, after `setGameId(game_id)`, add:

```ts
addGame(game_id, true);
```

In the `joinGame` mutation's `onSuccess`, after `setGameId(game_id)`, add:

```ts
addGame(game_id, false);
```

- [ ] **Step 3: Add game list state and delete mutation**

Inside the `HomePage` component, after the existing `useState` declarations, add:

```ts
const [games, setGames] = useState(() => getGames());

const endGame = useMutation({
  mutationFn: api.deleteGame,
  onSuccess: (_data, gameId) => {
    removeGame(gameId);
    setGames(getGames());
    setError(null);
  },
  onError: (e: Error, gameId) => {
    if (e.message === "Game not found") {
      removeGame(gameId);
      setGames(getGames());
    } else {
      setError(e.message);
    }
  },
});
```

- [ ] **Step 4: Add the Your Games UI**

In the JSX return (the main `return`, not the `createdGameId` early return), add this block after the closing `</div>` of the `flex flex-col gap-4 w-full max-w-sm` div, but still inside the outer wrapper div:

```tsx
{games.length > 0 && (
  <div className="w-full max-w-sm mt-2">
    <div className="flex items-center gap-2 text-slate-600 text-xs mb-3">
      <hr className="flex-1 border-slate-700" />
      <span>Your Games</span>
      <hr className="flex-1 border-slate-700" />
    </div>
    <div className="flex flex-col gap-2">
      {games.map((g) => (
        <div
          key={g.gameId}
          className="flex items-center justify-between bg-slate-800 border border-slate-700 rounded-lg px-3 py-2"
        >
          <div className="flex flex-col">
            <span className="font-mono text-yellow-300 text-xs">
              {g.gameId.slice(0, 8)}
            </span>
            <span className="text-slate-500 text-xs">
              {g.vsComputer ? "vs Computer" : "vs Human"}
            </span>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => {
                setGameId(g.gameId);
                navigate(`/game/${g.gameId}`);
              }}
              className="rounded bg-slate-700 hover:bg-slate-600 text-slate-100 text-xs font-semibold px-3 py-1"
            >
              Rejoin
            </button>
            <button
              onClick={() => endGame.mutate(g.gameId)}
              disabled={endGame.isPending}
              className="rounded bg-red-900 hover:bg-red-800 text-red-200 text-xs font-semibold px-3 py-1 disabled:opacity-50"
            >
              End
            </button>
          </div>
        </div>
      ))}
    </div>
  </div>
)}
```

- [ ] **Step 5: Refresh games list when returning to home page**

The `games` state is initialized once. To pick up changes (e.g., a game that was destroyed server-side), refresh on mount. Add a `useEffect` after the `useState` declarations:

```ts
React.useEffect(() => {
  setGames(getGames());
}, []);
```

This ensures the list is current every time the home page mounts (e.g., navigating back from a game).

- [ ] **Step 6: Commit**

```bash
git add app/frontend/components/HomePage.tsx
git commit -m "feat: show active games list on home page with rejoin and end actions"
```

---

### Task 6: Manual testing

- [ ] **Step 1: Start dev servers**

Run: `bin/dev`

- [ ] **Step 2: Test the full flow**

1. Open `http://localhost:3000` in a browser
2. Click "Start New Game" — verify it appears in "Your Games" section
3. Click browser back to return to home — verify the game still shows
4. Click "End" on the game — verify it disappears and you can now create a new game
5. Click "Play Computer" — verify it appears in the list
6. Click "Rejoin" — verify you land on the game page
7. Navigate back home — verify the game is listed

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec`

Expected: all specs pass, including the new DELETE specs.
