# Round Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 3-second auto-advance after scoring with a 10-second timer that cuts short when both players click "Ready".

**Architecture:** Two boolean columns on `games` track per-player confirmation. A new `POST confirm_round` controller action sets the flag and advances the round immediately if both are set. The 10-second `AdvanceRoundJob` is enqueued only from `place_card` (when the board fills) and exits harmlessly via its existing guard if the round already advanced.

**Tech Stack:** Rails 8, RSpec, React 18, TypeScript, Tailwind CSS, TanStack Query

---

## File Map

| File | Change |
|------|--------|
| `db/migrate/<timestamp>_add_scoring_confirmations_to_games.rb` | Create — new migration |
| `app/models/game.rb` | Modify — add `confirm_scoring!`, `both_scoring_confirmed?`, reset flags in `setup_round!` |
| `app/channels/game_channel.rb` | Modify — include new fields in broadcast |
| `app/controllers/api/games_controller.rb` | Modify — move job enqueue to `place_card`, 10s delay, add `confirm_round` action |
| `config/routes.rb` | Modify — add `post :confirm_round` member route |
| `app/frontend/types/game.ts` | Modify — add two boolean fields to `GameState` |
| `app/frontend/lib/api.ts` | Modify — add `confirmRound` method |
| `app/frontend/components/ScoringOverlay.tsx` | Modify — countdown 10, confirm button, per-player status |
| `app/frontend/components/GamePage.tsx` | Modify — wire `handleConfirmRound`, pass props to `ScoringOverlay` |
| `spec/models/game_spec.rb` | Modify — add tests for new model methods |
| `spec/requests/games_spec.rb` | Modify — add tests for `confirm_round` endpoint |
| `spec/channels/game_channel_spec.rb` | Modify — add new fields to broadcast assertion |

---

### Task 1: Migration

**Files:**
- Create: `db/migrate/<timestamp>_add_scoring_confirmations_to_games.rb`

- [ ] **Step 1: Generate and inspect the migration**

```bash
bin/rails generate migration AddScoringConfirmationsToGames \
  player1_confirmed_scoring:boolean \
  player2_confirmed_scoring:boolean
```

Open the generated file. It will be at `db/migrate/<timestamp>_add_scoring_confirmations_to_games.rb`. Replace its contents with:

```ruby
class AddScoringConfirmationsToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :player1_confirmed_scoring, :boolean, default: false, null: false
    add_column :games, :player2_confirmed_scoring, :boolean, default: false, null: false
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected output includes `AddScoringConfirmationsToGames: migrated`.

- [ ] **Step 3: Run the migration on the test database**

```bash
bin/rails db:migrate RAILS_ENV=test
```

- [ ] **Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add player1/2_confirmed_scoring columns to games"
```

---

### Task 2: Game Model — confirm_scoring! and both_scoring_confirmed?

**Files:**
- Modify: `app/models/game.rb`
- Modify: `spec/models/game_spec.rb`

- [ ] **Step 1: Write the failing tests**

Open `spec/models/game_spec.rb`. Add this describe block after the `#advance_round!` block (before the `scoring phase` block):

```ruby
describe "#confirm_scoring!" do
  let(:game) do
    g = create(:game, :active)
    g.deal!
    g.reload
    g.update!(status: "scoring")
    g
  end

  it "sets player1_confirmed_scoring when called for player1" do
    game.confirm_scoring!("player1")
    expect(game.reload.player1_confirmed_scoring).to be true
  end

  it "sets player2_confirmed_scoring when called for player2" do
    game.confirm_scoring!("player2")
    expect(game.reload.player2_confirmed_scoring).to be true
  end

  it "is idempotent — calling twice does not error" do
    game.confirm_scoring!("player1")
    expect { game.confirm_scoring!("player1") }.not_to raise_error
  end

  it "raises Game::Error when game is not in scoring phase" do
    active_game = create(:game, :active)
    active_game.deal!
    active_game.reload
    expect {
      active_game.confirm_scoring!("player1")
    }.to raise_error(Game::Error, /not in scoring phase/i)
  end
end

describe "#both_scoring_confirmed?" do
  let(:game) { create(:game, :active, status: "scoring") }

  it "returns false when neither player has confirmed" do
    expect(game.both_scoring_confirmed?).to be false
  end

  it "returns false when only player1 has confirmed" do
    game.update!(player1_confirmed_scoring: true)
    expect(game.both_scoring_confirmed?).to be false
  end

  it "returns false when only player2 has confirmed" do
    game.update!(player2_confirmed_scoring: true)
    expect(game.both_scoring_confirmed?).to be false
  end

  it "returns true when both players have confirmed" do
    game.update!(player1_confirmed_scoring: true, player2_confirmed_scoring: true)
    expect(game.both_scoring_confirmed?).to be true
  end
end
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
bundle exec rspec spec/models/game_spec.rb --format documentation 2>&1 | grep -E "confirm_scoring|both_scoring"
```

Expected: several failures with "undefined method".

- [ ] **Step 3: Implement the model methods**

Open `app/models/game.rb`. After the `discard_to_crib!` method (around line 89) and before `advance_round!`, add:

```ruby
def confirm_scoring!(slot)
  raise Error, "Game is not in scoring phase" unless status == "scoring"
  send("#{slot}_confirmed_scoring=", true)
  save!
end

def both_scoring_confirmed?
  player1_confirmed_scoring && player2_confirmed_scoring
end
```

- [ ] **Step 4: Reset flags in setup_round!**

Open `app/models/game.rb`. Inside the `setup_round!` private method, add two lines after the `self.crib_score = nil` line:

```ruby
self.player1_confirmed_scoring = false
self.player2_confirmed_scoring = false
```

The surrounding context will look like:

```ruby
self.crib_score            = nil
self.player1_confirmed_scoring = false
self.player2_confirmed_scoring = false

# Nibs: starter is a Jack → crib owner scores 2 pts
```

- [ ] **Step 5: Run the tests to confirm they pass**

```bash
bundle exec rspec spec/models/game_spec.rb --format documentation 2>&1 | grep -E "confirm_scoring|both_scoring|advance_round"
```

Expected: all new tests pass, existing `#advance_round!` tests still pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/game.rb spec/models/game_spec.rb
git commit -m "feat: add confirm_scoring! and both_scoring_confirmed? to Game model"
```

---

### Task 3: Serialization — include confirmation flags in HTTP and broadcast

**Files:**
- Modify: `app/models/game.rb`
- Modify: `app/channels/game_channel.rb`
- Modify: `spec/models/game_spec.rb`
- Modify: `spec/channels/game_channel_spec.rb`

- [ ] **Step 1: Write failing test for serialize_for**

Open `spec/models/game_spec.rb`. Find the `#serialize_for` describe block. Update the `"includes all required fields for player1"` test to also expect the new keys:

```ruby
it "includes all required fields for player1" do
  result = game.serialize_for(game.player1_token)
  expect(result).to include(
    :id, :status, :current_turn, :round, :crib_owner,
    :board, :starter_card, :row_scores, :col_scores,
    :crib_score, :crib_size, :deck_size,
    :player1_peg, :player2_peg, :winner_slot,
    :my_slot, :my_next_card,
    :player1_confirmed_scoring, :player2_confirmed_scoring
  )
end
```

Also add a test for the broadcast in `spec/channels/game_channel_spec.rb`. In the `".broadcast_game_state"` describe block, add after the existing tests:

```ruby
it "includes player confirmation flags in the broadcast" do
  game.deal!
  expect {
    GameChannel.broadcast_game_state(game)
  }.to have_broadcasted_to("game_#{game.id}").with(
    hash_including(
      "player1_confirmed_scoring" => false,
      "player2_confirmed_scoring" => false
    )
  )
end
```

- [ ] **Step 2: Run the failing tests**

```bash
bundle exec rspec spec/models/game_spec.rb spec/channels/game_channel_spec.rb --format documentation 2>&1 | grep -E "confirmed_scoring|FAILED|failed"
```

Expected: the two new assertions fail.

- [ ] **Step 3: Update serialize_for in Game model**

Open `app/models/game.rb`. In the `serialize_for` method, add the two new fields to the returned hash (after `winner_slot:`):

```ruby
winner_slot:   winner_slot,
player1_confirmed_scoring: player1_confirmed_scoring,
player2_confirmed_scoring: player2_confirmed_scoring,
my_slot:       slot,
my_next_card:  slot ? send("#{slot}_deck").first : nil
```

- [ ] **Step 4: Update broadcast_game_state in GameChannel**

Open `app/channels/game_channel.rb`. In the `broadcast_game_state` method, add the two fields to the hash (after `winner_slot:`):

```ruby
winner_slot:  game.winner_slot,
player1_confirmed_scoring: game.player1_confirmed_scoring,
player2_confirmed_scoring: game.player2_confirmed_scoring
```

- [ ] **Step 5: Run the tests to confirm they pass**

```bash
bundle exec rspec spec/models/game_spec.rb spec/channels/game_channel_spec.rb --format documentation
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/game.rb app/channels/game_channel.rb \
        spec/models/game_spec.rb spec/channels/game_channel_spec.rb
git commit -m "feat: include confirmation flags in game serialization and broadcast"
```

---

### Task 4: Routes + Controller — confirm_round action, 10s delay

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/games_controller.rb`
- Modify: `spec/requests/games_spec.rb`

- [ ] **Step 1: Write failing request specs**

Open `spec/requests/games_spec.rb`. Add this describe block after the `discard_to_crib` block:

```ruby
describe "POST /api/games/:id/confirm_round" do
  let(:game) { create(:game, :active) }

  before do
    game.deal!
    game.reload
    game.update!(status: "scoring")
  end

  it "sets the confirming player's flag and returns ok" do
    post "/api/games/#{game.id}/confirm_round",
         headers: { "X-Player-Token" => game.player1_token }
    expect(response).to have_http_status(:ok)
    expect(game.reload.player1_confirmed_scoring).to be true
  end

  it "advances the round immediately when both players confirm" do
    post "/api/games/#{game.id}/confirm_round",
         headers: { "X-Player-Token" => game.player1_token }
    post "/api/games/#{game.id}/confirm_round",
         headers: { "X-Player-Token" => game.player2_token }
    expect(response).to have_http_status(:ok)
    expect(game.reload.status).to eq("active")
    expect(game.reload.round).to eq(2)
  end

  it "returns error when called outside scoring phase" do
    non_scoring = create(:game, :active)
    non_scoring.deal!
    non_scoring.reload
    post "/api/games/#{non_scoring.id}/confirm_round",
         headers: { "X-Player-Token" => non_scoring.player1_token }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns 401 without a token" do
    post "/api/games/#{game.id}/confirm_round"
    expect(response).to have_http_status(:unauthorized)
  end
end
```

- [ ] **Step 2: Run to confirm the tests fail**

```bash
bundle exec rspec spec/requests/games_spec.rb --format documentation 2>&1 | grep -E "confirm_round|FAILED|No route"
```

Expected: routing error "No route matches".

- [ ] **Step 3: Add the route**

Open `config/routes.rb`. Add `post :confirm_round` to the `member do` block:

```ruby
member do
  post :join
  post :place_card
  post :discard_to_crib
  post :confirm_round
end
```

- [ ] **Step 4: Update the controller**

Open `app/controllers/api/games_controller.rb`. Make three changes:

**Change 1** — Add `confirm_round` to `GAME_ACTIONS`:
```ruby
GAME_ACTIONS = %i[show place_card discard_to_crib confirm_round].freeze
```

**Change 2** — Move the `AdvanceRoundJob` enqueue into `place_card` and change delay to 10 seconds. Replace the `place_card` action:
```ruby
# POST /api/games/:id/place_card  { row: int, col: int }
def place_card
  game_action do
    @game.place_card!(current_slot, params[:row].to_i, params[:col].to_i)
    AdvanceRoundJob.set(wait: 10.seconds).perform_later(@game.id) if @game.status == "scoring"
  end
end
```

**Change 3** — Add the `confirm_round` action (after `discard_to_crib`):
```ruby
# POST /api/games/:id/confirm_round
def confirm_round
  game_action do
    @game.confirm_scoring!(current_slot)
    @game.advance_round! if @game.both_scoring_confirmed?
  end
end
```

**Change 4** — Remove the `AdvanceRoundJob` line from the `game_action` helper. The updated helper:
```ruby
def game_action(&block)
  block.call
  GameChannel.broadcast_game_state(@game)
  render json: @game.serialize_for(@current_token)
rescue Game::Error => e
  render_error(e.message)
end
```

- [ ] **Step 5: Run the request specs to confirm they pass**

```bash
bundle exec rspec spec/requests/games_spec.rb --format documentation
```

Expected: all pass, including all four new `confirm_round` tests.

- [ ] **Step 6: Run the full test suite to check for regressions**

```bash
bundle exec rspec --format progress
```

Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/api/games_controller.rb \
        spec/requests/games_spec.rb
git commit -m "feat: add confirm_round action and move AdvanceRoundJob to place_card (10s delay)"
```

---

### Task 5: Frontend types + API client

**Files:**
- Modify: `app/frontend/types/game.ts`
- Modify: `app/frontend/lib/api.ts`

- [ ] **Step 1: Add confirmation fields to GameState**

Open `app/frontend/types/game.ts`. Add two fields to the `GameState` interface, after `winner_slot`:

```typescript
winner_slot: "player1" | "player2" | null;
player1_confirmed_scoring: boolean;
player2_confirmed_scoring: boolean;
// Private — only included in HTTP responses, never in broadcasts
my_slot: "player1" | "player2" | null;
my_next_card: Card | null;
```

`GameChannelMessage` uses `Omit<GameState, "id" | "my_slot" | "my_next_card">` so the new fields are automatically included in broadcasts — no change needed there.

- [ ] **Step 2: Add confirmRound to the API client**

Open `app/frontend/lib/api.ts`. Add `confirmRound` to the `api` object, after `discardToCrib`:

```typescript
confirmRound: (id: string): Promise<GameState> =>
  request("POST", `/games/${id}/confirm_round`),
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
npm run build 2>&1 | head -30
```

Expected: no TypeScript errors (build may fail for other reasons like missing imports, but no type errors on these files).

- [ ] **Step 4: Commit**

```bash
git add app/frontend/types/game.ts app/frontend/lib/api.ts
git commit -m "feat: add confirmation fields to GameState and confirmRound to api client"
```

---

### Task 6: ScoringOverlay — countdown 10, confirm button, per-player status

**Files:**
- Modify: `app/frontend/components/ScoringOverlay.tsx`

- [ ] **Step 1: Replace ScoringOverlay with updated version**

Open `app/frontend/components/ScoringOverlay.tsx` and replace the entire file:

```tsx
// app/frontend/components/ScoringOverlay.tsx
import React, { useEffect, useState } from "react";
import type { GameState } from "../types/game";

interface ScoringOverlayProps {
  game: GameState;
  mySlot: "player1" | "player2";
  onConfirm: () => void;
  isConfirmPending: boolean;
}

export function ScoringOverlay({ game, mySlot, onConfirm, isConfirmPending }: ScoringOverlayProps) {
  const [countdown, setCountdown] = useState(10);

  useEffect(() => {
    if (game.status !== "scoring") return;
    setCountdown(10);
    const interval = setInterval(() => {
      setCountdown((n) => Math.max(0, n - 1));
    }, 1000);
    return () => clearInterval(interval);
  }, [game.status, game.round]);

  if (game.status !== "scoring") return null;

  const myScores  = mySlot === "player1" ? game.col_scores : game.row_scores;
  const oppScores = mySlot === "player1" ? game.row_scores : game.col_scores;
  const myTotal   = myScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner === mySlot ? (game.crib_score ?? 0) : 0);
  const oppTotal  = oppScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner !== null && game.crib_owner !== mySlot ? (game.crib_score ?? 0) : 0);

  const iConfirmed       = mySlot === "player1"
    ? game.player1_confirmed_scoring
    : game.player2_confirmed_scoring;
  const opponentConfirmed = mySlot === "player1"
    ? game.player2_confirmed_scoring
    : game.player1_confirmed_scoring;

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-slate-900 border border-slate-700 rounded-xl p-6 max-w-sm w-full">
        <h2 className="text-yellow-400 font-black text-xl text-center mb-4">Round {game.round} Scores</h2>

        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-green-400 text-xs font-semibold mb-1">Your hands</p>
            {myScores.map((s, i) => (
              <div key={i} className="flex justify-between text-sm font-mono">
                <span className="text-slate-400">Hand {i + 1}</span>
                <span className="text-green-300">{s ?? 0}</span>
              </div>
            ))}
            {game.crib_owner === mySlot && (
              <div className="flex justify-between text-sm font-mono border-t border-slate-700 mt-1 pt-1">
                <span className="text-yellow-400">Crib</span>
                <span className="text-yellow-300">{game.crib_score ?? 0}</span>
              </div>
            )}
            <div className="flex justify-between text-sm font-mono font-bold border-t border-slate-600 mt-1 pt-1">
              <span className="text-slate-300">Total</span>
              <span className="text-green-400">{myTotal}</span>
            </div>
          </div>

          <div>
            <p className="text-blue-400 text-xs font-semibold mb-1">Opponent's hands</p>
            {oppScores.map((s, i) => (
              <div key={i} className="flex justify-between text-sm font-mono">
                <span className="text-slate-400">Hand {i + 1}</span>
                <span className="text-blue-300">{s ?? 0}</span>
              </div>
            ))}
            {game.crib_owner !== null && game.crib_owner !== mySlot && (
              <div className="flex justify-between text-sm font-mono border-t border-slate-700 mt-1 pt-1">
                <span className="text-yellow-400">Crib</span>
                <span className="text-yellow-300">{game.crib_score ?? 0}</span>
              </div>
            )}
            <div className="flex justify-between text-sm font-mono font-bold border-t border-slate-600 mt-1 pt-1">
              <span className="text-slate-300">Total</span>
              <span className="text-blue-400">{oppTotal}</span>
            </div>
          </div>
        </div>

        <div className="text-center">
          {myTotal > oppTotal && <p className="text-green-400 font-bold mb-2">You lead by {myTotal - oppTotal} pts</p>}
          {oppTotal > myTotal && <p className="text-red-400 font-bold mb-2">Opponent leads by {oppTotal - myTotal} pts</p>}
          {myTotal === oppTotal && <p className="text-slate-400 mb-2">Tied this round</p>}

          <button
            onClick={onConfirm}
            disabled={iConfirmed || isConfirmPending}
            className="w-full mt-2 mb-3 px-4 py-2 rounded-lg font-semibold text-sm bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white transition-colors"
          >
            {iConfirmed ? "Ready" : "Ready for next round"}
          </button>

          <div className="flex justify-between text-xs mb-2">
            <span className={iConfirmed ? "text-green-400" : "text-slate-500"}>
              You: {iConfirmed ? "Ready ✓" : "waiting…"}
            </span>
            <span className={opponentConfirmed ? "text-green-400" : "text-slate-500"}>
              Opponent: {opponentConfirmed ? "Ready ✓" : "waiting…"}
            </span>
          </div>

          <p className="text-slate-500 text-sm">Next round in {countdown}…</p>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
npm run build 2>&1 | grep -E "error TS|ScoringOverlay"
```

Expected: no errors on ScoringOverlay (there will be a prop mismatch error from GamePage until Task 7).

- [ ] **Step 3: Commit**

```bash
git add app/frontend/components/ScoringOverlay.tsx
git commit -m "feat: update ScoringOverlay with 10s countdown, confirm button, and per-player status"
```

---

### Task 7: GamePage — wire handleConfirmRound

**Files:**
- Modify: `app/frontend/components/GamePage.tsx`

- [ ] **Step 1: Add handleConfirmRound and update ScoringOverlay usage**

Open `app/frontend/components/GamePage.tsx`. 

Add `handleConfirmRound` after `handleDiscard` (around line 82):

```typescript
function handleConfirmRound() {
  action.mutate(() => api.confirmRound(gid));
}
```

Update the `ScoringOverlay` usage (around line 139) to pass the new props:

```tsx
<ScoringOverlay
  game={game}
  mySlot={mySlot}
  onConfirm={handleConfirmRound}
  isConfirmPending={action.isPending}
/>
```

- [ ] **Step 2: Verify TypeScript compiles cleanly**

```bash
npm run build 2>&1 | grep "error TS"
```

Expected: no TypeScript errors.

- [ ] **Step 3: Run the full backend test suite one more time**

```bash
bundle exec rspec --format progress
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add app/frontend/components/GamePage.tsx
git commit -m "feat: wire confirm round action in GamePage"
```

---

## Done

All seven tasks complete. The scoring overlay now:
- Shows a 10-second countdown
- Has a "Ready for next round" button per player
- Shows per-player confirmation status in real time
- Advances immediately when both players confirm
- Falls back to the 10-second auto-advance if one or both players don't confirm
