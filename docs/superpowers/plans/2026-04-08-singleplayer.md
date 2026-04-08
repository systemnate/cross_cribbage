# Single-Player (vs Computer) Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Play Computer" button so a player can immediately start a game against a server-side AI that uses greedy one-move lookahead to place cards.

**Architecture:** A `vs_computer` boolean on `Game` triggers two new background jobs — `ComputerMoveJob` (places cards, 2s delay) and `ComputerConfirmJob` (confirms scoring, 2s delay) — via a `maybe_enqueue_computer_jobs!` hook added to the end of each state-mutating game method. AI decision logic lives in an isolated `ComputerPlayer` class that simulates every empty cell using the existing `CribbageHand` scorer. The AI always plays as player2.

**Tech Stack:** Ruby on Rails 8, Active Job (Solid Queue), RSpec + FactoryBot, React + TypeScript, TanStack Query

---

## File Structure

**Create:**
- `db/migrate/TIMESTAMP_add_vs_computer_to_games.rb`
- `app/lib/computer_player.rb`
- `app/jobs/computer_move_job.rb`
- `app/jobs/computer_confirm_job.rb`
- `spec/lib/computer_player_spec.rb`
- `spec/jobs/computer_move_job_spec.rb`
- `spec/jobs/computer_confirm_job_spec.rb`

**Modify:**
- `app/models/game.rb` — `serialize_for`, `maybe_enqueue_computer_jobs!`, trigger hooks in `deal!`, `place_card!`, `discard_to_crib!`, `advance_round!`
- `app/controllers/api/games_controller.rb` — `create` action
- `spec/requests/games_spec.rb` — vs_computer creation test
- `app/frontend/types/game.ts` — `vs_computer` field
- `app/frontend/lib/api.ts` — `createGame` signature
- `app/frontend/components/HomePage.tsx` — "Play Computer" button

---

### Task 1: Add `vs_computer` column to games

**Files:**
- Create: `db/migrate/TIMESTAMP_add_vs_computer_to_games.rb`

- [ ] **Step 1: Generate migration**

```bash
cd /path/to/cross_cribbage && bin/rails generate migration AddVsComputerToGames vs_computer:boolean
```

Expected: creates `db/migrate/TIMESTAMP_add_vs_computer_to_games.rb`

- [ ] **Step 2: Open the generated migration and verify it looks like this** (the generator should produce this, but confirm):

```ruby
class AddVsComputerToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :vs_computer, :boolean, default: false, null: false
  end
end
```

If `default: false, null: false` is missing, add it.

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected output includes: `AddVsComputerToGames: migrated`

- [ ] **Step 4: Verify schema**

```bash
grep -A 2 "vs_computer" db/schema.rb
```

Expected: `t.boolean "vs_computer", default: false, null: false`

- [ ] **Step 5: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add vs_computer column to games"
```

---

### Task 2: ComputerPlayer — AI decision logic (TDD)

**Files:**
- Create: `spec/lib/computer_player_spec.rb`
- Create: `app/lib/computer_player.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/lib/computer_player_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ComputerPlayer do
  # Build a minimal card hash
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  def empty_board
    Array.new(5) { Array.new(5, nil) }
  end

  def nil_scores
    [nil, nil, nil, nil, nil]
  end

  # --- Scenario: no scoring combos possible (all cells give net_impact = 0)
  # A lone "2" on any empty row/col scores 0 points. Net impact = 0 everywhere.
  # Since 0 <= 0 and crib has space → should discard.
  describe "#decide with all-zero net impact and crib space" do
    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 empty_board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("3", "♥", "c2"),
        player2_crib_discards: 0
      )
    end

    it "returns :discard" do
      expect(described_class.new(game).decide).to eq({ action: :discard })
    end
  end

  # --- Same scenario but crib is full (discards == 2) → must place
  describe "#decide with all-zero net impact but crib full" do
    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 empty_board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("3", "♥", "c2"),
        player2_crib_discards: 2
      )
    end

    it "returns :place with a valid empty cell" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to be_between(0, 4)
      expect(result[:col]).to be_between(0, 4)
    end
  end

  # --- Scenario: row 0 has 5♠ and 10♥. Next card is 5♦.
  # Placing 5♦ in row 0 scores: pair(5♠,5♦)=2 + fifteen(5♠+10♥)=2 + fifteen(5♦+10♥)=2 = 6.
  # Placing 5♦ in any other row scores 0 (lone card, no combos with A starter).
  # Net impact for row 0 cells = 6 - 0 = 6. For all other cells = 0 - 0 = 0.
  # Best cell should be the first empty cell in row 0 (col 2, since 0 and 1 are occupied).
  describe "#decide picks the cell with highest net impact" do
    let(:board) do
      b = empty_board
      b[0][0] = card("5", "♠", "c1")
      b[0][1] = card("10", "♥", "c2")
      b
    end

    let(:game) do
      create(:game,
        player2_deck:          [card("5", "♦", "c3")],
        board:                 board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("A", "♣", "c4"),
        player2_crib_discards: 2   # force placement
      )
    end

    it "places in row 0 (highest net row impact)" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to eq(0)
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
bin/rspec spec/lib/computer_player_spec.rb
```

Expected: `LoadError` — `computer_player.rb` does not exist yet.

- [ ] **Step 3: Implement ComputerPlayer**

Create `app/lib/computer_player.rb`:

```ruby
# frozen_string_literal: true

class ComputerPlayer
  # AI always plays as player2.
  # player2 scores rows; player1 (opponent) scores columns.
  def initialize(game)
    @game = game
  end

  # Returns { action: :place, row: Integer, col: Integer }
  #      or { action: :discard }
  def decide
    next_card = @game.player2_deck.first
    return { action: :discard } unless next_card

    best_move       = nil
    best_net_impact = nil

    5.times do |row|
      5.times do |col|
        next if @game.board[row][col]  # occupied

        net_impact = simulate_net_impact(row, col, next_card)

        if best_net_impact.nil? || net_impact > best_net_impact
          best_net_impact = net_impact
          best_move = { action: :place, row: row, col: col }
        end
      end
    end

    # Prefer discarding over a net-neutral/negative move if crib still has room.
    if best_net_impact && best_net_impact <= 0 && @game.player2_crib_discards < 2
      return { action: :discard }
    end

    best_move || { action: :discard }
  end

  private

  def simulate_net_impact(row, col, card)
    current_row_score = @game.row_scores[row].to_i
    current_col_score = @game.col_scores[col].to_i

    row_cards = @game.board[row].each_with_index.map { |c, i| i == col ? card : c }.compact
    col_cards = @game.board.each_with_index.map { |r, i| i == row ? card : r[col] }.compact

    new_row_score = CribbageHand.new(row_cards, starter: @game.starter_card, is_center: row == 2).score
    new_col_score = CribbageHand.new(col_cards, starter: @game.starter_card, is_center: col == 2).score

    (new_row_score - current_row_score) - (new_col_score - current_col_score)
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bin/rspec spec/lib/computer_player_spec.rb
```

Expected: `3 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/lib/computer_player.rb spec/lib/computer_player_spec.rb
git commit -m "feat: add ComputerPlayer AI decision logic"
```

---

### Task 3: ComputerMoveJob (TDD)

**Files:**
- Create: `spec/jobs/computer_move_job_spec.rb`
- Create: `app/jobs/computer_move_job.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/jobs/computer_move_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ComputerMoveJob, type: :job do
  let(:game_channel_double) { double("GameChannel", broadcast_game_state: nil) }

  before { stub_const("GameChannel", game_channel_double) }

  def card(rank, suit)
    { "rank" => rank, "suit" => suit, "id" => SecureRandom.uuid }
  end

  # A minimal active vs-computer game where it's player2's turn.
  # player2 has one card (5♠) and has already discarded 2 (so it must place).
  # The board is empty so any cell is valid.
  let(:game) do
    create(:game,
      status:                "active",
      vs_computer:           true,
      player1_token:         Game.generate_token,
      player2_token:         Game.generate_token,
      current_turn:          "player2",
      crib_owner:            "player1",
      board:                 Array.new(5) { Array.new(5, nil) },
      row_scores:            [nil, nil, nil, nil, nil],
      col_scores:            [nil, nil, nil, nil, nil],
      starter_card:          card("A", "♣"),
      player1_deck:          [card("2", "♥")],
      player2_deck:          [card("5", "♠")],
      player2_crib_discards: 2
    )
  end

  describe "#perform" do
    it "places a card and broadcasts" do
      expect(game_channel_double).to receive(:broadcast_game_state)
      described_class.new.perform(game.id)

      game.reload
      placed = game.board.flatten.compact
      expect(placed.size).to eq(1)
      expect(placed.first["rank"]).to eq("5")
    end

    it "does nothing if game is not active" do
      game.update!(status: "waiting")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if it is not player2's turn" do
      game.update!(current_turn: "player1")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if game does not exist" do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
bin/rspec spec/jobs/computer_move_job_spec.rb
```

Expected: `LoadError` — `computer_move_job.rb` does not exist yet.

- [ ] **Step 3: Implement ComputerMoveJob**

Create `app/jobs/computer_move_job.rb`:

```ruby
# frozen_string_literal: true

class ComputerMoveJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.status == "active"
    return unless game.current_turn == "player2"
    return unless game.vs_computer?

    decision = ComputerPlayer.new(game).decide

    case decision[:action]
    when :discard
      game.discard_to_crib!("player2")
    when :place
      game.place_card!("player2", decision[:row], decision[:col])
    end

    GameChannel.broadcast_game_state(game)
  rescue Game::Error
    # Game state changed between enqueue and execution; skip silently.
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bin/rspec spec/jobs/computer_move_job_spec.rb
```

Expected: `4 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/jobs/computer_move_job.rb spec/jobs/computer_move_job_spec.rb
git commit -m "feat: add ComputerMoveJob"
```

---

### Task 4: ComputerConfirmJob (TDD)

**Files:**
- Create: `spec/jobs/computer_confirm_job_spec.rb`
- Create: `app/jobs/computer_confirm_job.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/jobs/computer_confirm_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ComputerConfirmJob, type: :job do
  let(:game_channel_double) { double("GameChannel", broadcast_game_state: nil) }

  before { stub_const("GameChannel", game_channel_double) }

  let(:game) do
    create(:game,
      status:                    "scoring",
      vs_computer:               true,
      player1_token:             Game.generate_token,
      player2_token:             Game.generate_token,
      crib_owner:                "player1",
      current_turn:              nil,
      board:                     Array.new(5) { Array.new(5, nil) },
      row_scores:                [nil, nil, nil, nil, nil],
      col_scores:                [nil, nil, nil, nil, nil],
      starter_card:              { "rank" => "A", "suit" => "♣", "id" => SecureRandom.uuid },
      player1_confirmed_scoring: false,
      player2_confirmed_scoring: false,
      player1_deck:              [],
      player2_deck:              [],
      crib:                      []
    )
  end

  describe "#perform" do
    it "confirms scoring for player2 and broadcasts" do
      expect(game_channel_double).to receive(:broadcast_game_state)
      described_class.new.perform(game.id)

      game.reload
      expect(game.player2_confirmed_scoring).to be(true)
    end

    it "advances the round when both players have confirmed" do
      game.update!(player1_confirmed_scoring: true)
      expect(game_channel_double).to receive(:broadcast_game_state)

      described_class.new.perform(game.id)

      game.reload
      expect(game.status).to eq("active")
      expect(game.round).to eq(2)
    end

    it "does nothing if game is not in scoring phase" do
      game.update!(status: "active")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if player2 already confirmed" do
      game.update!(player2_confirmed_scoring: true)
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if game does not exist" do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
bin/rspec spec/jobs/computer_confirm_job_spec.rb
```

Expected: `LoadError` — `computer_confirm_job.rb` does not exist yet.

- [ ] **Step 3: Implement ComputerConfirmJob**

Create `app/jobs/computer_confirm_job.rb`:

```ruby
# frozen_string_literal: true

class ComputerConfirmJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.status == "scoring"
    return if game.player2_confirmed_scoring

    game.confirm_scoring!("player2")
    game.advance_round! if game.both_scoring_confirmed?
    GameChannel.broadcast_game_state(game)
  rescue Game::Error
    # Ignore — game state changed between enqueue and execution.
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bin/rspec spec/jobs/computer_confirm_job_spec.rb
```

Expected: `5 examples, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add app/jobs/computer_confirm_job.rb spec/jobs/computer_confirm_job_spec.rb
git commit -m "feat: add ComputerConfirmJob"
```

---

### Task 5: Game model — serialize and enqueue hooks

**Files:**
- Modify: `app/models/game.rb`

- [ ] **Step 1: Add `vs_computer` to `serialize_for`**

In `app/models/game.rb`, find the `serialize_for` method. Add `vs_computer: vs_computer` to the returned hash. The full hash (with the new field) should look like:

```ruby
def serialize_for(token)
  slot = player_slot(token)
  {
    id:            id,
    status:        status,
    current_turn:  current_turn,
    round:         round,
    crib_owner:    crib_owner,
    board:         board,
    starter_card:  starter_card,
    row_scores:    row_scores,
    col_scores:    col_scores,
    crib_score:    crib_score,
    crib_size:     { player1: player1_crib_discards, player2: player2_crib_discards },
    deck_size:     { player1: player1_deck.size,     player2: player2_deck.size },
    player1_peg:   player1_peg,
    player2_peg:   player2_peg,
    winner_slot:   winner_slot,
    player1_confirmed_scoring: player1_confirmed_scoring,
    player2_confirmed_scoring: player2_confirmed_scoring,
    crib_hand:     status == "scoring" ? crib : nil,
    vs_computer:   vs_computer,
    my_slot:       slot,
    my_next_card:  slot ? send("#{slot}_deck").first : nil
  }
end
```

- [ ] **Step 2: Add `maybe_enqueue_computer_jobs!` to the private section**

In `app/models/game.rb`, at the bottom of the `private` section (after `assert_active_turn!`), add:

```ruby
# NOTE: No delay for now — add `.set(wait: 2.seconds)` before `.perform_later` once
# the feature is verified working.
def maybe_enqueue_computer_jobs!
  return unless vs_computer?

  if status == "active" && current_turn == "player2"
    ComputerMoveJob.perform_later(id)
  elsif status == "scoring" && !player2_confirmed_scoring
    ComputerConfirmJob.perform_later(id)
  end
end
```

- [ ] **Step 3: Add the hook call to `deal!`, `place_card!`, `discard_to_crib!`, and `advance_round!`**

In each of these four methods, add `maybe_enqueue_computer_jobs!` immediately after `save!`. The updated methods look like:

```ruby
def deal!
  self.crib_owner   = %w[player1 player2].sample
  self.current_turn = opposite(crib_owner)
  setup_round!
  self.status = "active"
  save!
  maybe_enqueue_computer_jobs!
end

def place_card!(slot, row, col)
  assert_active_turn!(slot)
  raise Error, "Invalid position" unless row.between?(0, 4) && col.between?(0, 4)

  remaining_crib = 2 - send("#{slot}_crib_discards")
  raise Error, "Must discard to crib first" if send("#{slot}_deck").size <= remaining_crib

  current_board = board.map(&:dup)
  raise Error, "Cell is occupied" if current_board[row][col]

  card = pop_top_card!(slot)
  current_board[row][col] = card
  self.board = current_board

  rescore_row!(row)
  rescore_col!(col)

  if board_full?
    flush_remaining_to_crib!
    enter_scoring_phase!
  else
    flip_turn!
  end

  save!
  maybe_enqueue_computer_jobs!
end

def discard_to_crib!(slot)
  assert_active_turn!(slot)
  raise Error, "Already discarded 2 cards to the crib" if send("#{slot}_crib_discards") >= 2

  card = pop_top_card!(slot)
  self.crib = crib + [card]
  self.send("#{slot}_crib_discards=", send("#{slot}_crib_discards") + 1)

  # Discards never fill the board (only place_card! does), so always flip turn.
  flip_turn!

  save!
  maybe_enqueue_computer_jobs!
end

def advance_round!
  self.round         += 1
  new_crib_owner      = opposite(crib_owner)
  self.crib_owner     = new_crib_owner
  self.current_turn   = opposite(new_crib_owner)   # non-crib player goes first
  setup_round!
  self.status = "active"
  save!
  maybe_enqueue_computer_jobs!
end
```

- [ ] **Step 4: Run the full model spec to confirm nothing broke**

```bash
bin/rspec spec/models/game_spec.rb
```

Expected: all existing examples pass.

- [ ] **Step 5: Run the job specs too**

```bash
bin/rspec spec/jobs/computer_move_job_spec.rb spec/jobs/computer_confirm_job_spec.rb
```

Expected: all pass. In test mode, `perform_later` enqueues jobs without executing them, so `maybe_enqueue_computer_jobs!` calls inside the job's model operations cause no interference.

- [ ] **Step 6: Commit**

```bash
git add app/models/game.rb
git commit -m "feat: wire ComputerMoveJob and ComputerConfirmJob into game state transitions"
```

---

### Task 6: API controller — vs_computer game creation

**Files:**
- Modify: `app/controllers/api/games_controller.rb`
- Modify: `spec/requests/games_spec.rb`

- [ ] **Step 1: Write the failing test**

In `spec/requests/games_spec.rb`, add inside the `describe "POST /api/games"` block:

```ruby
it "creates a vs-computer game that is immediately active" do
  post "/api/games", params: { vs_computer: true }, as: :json
  expect(response).to have_http_status(:created)
  expect(json).to include("game_id", "token")

  game = Game.find(json["game_id"])
  expect(game.vs_computer).to be(true)
  expect(game.status).to eq("active")
  expect(game.player2_token).to be_present
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
bin/rspec spec/requests/games_spec.rb -e "vs-computer"
```

Expected: `FAILED` — game status is still `"waiting"`.

- [ ] **Step 3: Update the `create` action**

In `app/controllers/api/games_controller.rb`, replace the `create` action:

```ruby
# POST /api/games
def create
  token = Game.generate_token
  game  = Game.create!(player1_token: token)

  if params[:vs_computer]
    game.update!(player2_token: Game.generate_token, vs_computer: true)
    game.deal!
  end

  DestroyGameJob.set(wait: 2.hours).perform_later(game.id)
  render json: { game_id: game.id, token: token }, status: :created
end
```

- [ ] **Step 4: Run the request spec**

```bash
bin/rspec spec/requests/games_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/games_controller.rb spec/requests/games_spec.rb
git commit -m "feat: support vs_computer param in POST /api/games"
```

---

### Task 7: Frontend types and API client

**Files:**
- Modify: `app/frontend/types/game.ts`
- Modify: `app/frontend/lib/api.ts`

- [ ] **Step 1: Add `vs_computer` to GameState**

In `app/frontend/types/game.ts`, add `vs_computer: boolean;` to the `GameState` interface. Place it after `winner_slot`:

```typescript
winner_slot: "player1" | "player2" | null;
player1_confirmed_scoring: boolean;
player2_confirmed_scoring: boolean;
crib_hand: Card[] | null;
vs_computer: boolean;
// Private — only included in HTTP responses, never in broadcasts
my_slot: "player1" | "player2" | null;
my_next_card: Card | null;
```

- [ ] **Step 2: Update `createGame` in api.ts**

In `app/frontend/lib/api.ts`, change the `createGame` entry in the `api` object from:

```typescript
createGame: (): Promise<CreateGameResponse> =>
  request("POST", "/games"),
```

to:

```typescript
createGame: (options?: { vs_computer?: boolean }): Promise<CreateGameResponse> =>
  request("POST", "/games", options),
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd app/frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add app/frontend/types/game.ts app/frontend/lib/api.ts
git commit -m "feat: add vs_computer to GameState type and createGame API call"
```

---

### Task 8: HomePage — "Play Computer" button

**Files:**
- Modify: `app/frontend/components/HomePage.tsx`

- [ ] **Step 1: Add the `playComputer` mutation and button**

Replace the entire contents of `app/frontend/components/HomePage.tsx` with:

```typescript
import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { setToken, setGameId, clearSession } from "../lib/storage";
import { resetConsumer } from "../lib/cable";

export function HomePage() {
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [createdGameId, setCreatedGameId] = useState<string | null>(null);

  const createGame = useMutation({
    mutationFn: api.createGame,
    onMutate: () => setError(null),
    onSuccess: ({ game_id, token }) => {
      clearSession();
      resetConsumer();
      setToken(token);
      setGameId(game_id);
      setCreatedGameId(game_id);
    },
    onError: (e: Error) => setError(e.message),
  });

  const playComputer = useMutation({
    mutationFn: () => api.createGame({ vs_computer: true }),
    onMutate: () => setError(null),
    onSuccess: ({ game_id, token }) => {
      clearSession();
      resetConsumer();
      setToken(token);
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  const joinGame = useMutation({
    mutationFn: () => api.joinGame(joinId.trim()),
    onMutate: () => setError(null),
    onSuccess: ({ game_id, token }) => {
      clearSession();
      resetConsumer();
      setToken(token);
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  if (createdGameId) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
        <h1 className="text-3xl font-black text-green-400">Game created!</h1>
        <p className="text-slate-400 text-sm">Share this ID with your opponent:</p>
        <div className="bg-slate-800 border border-slate-600 rounded-lg px-6 py-3 font-mono text-yellow-300 text-sm select-all">
          {createdGameId}
        </div>
        <p className="text-slate-500 text-xs">Waiting for opponent to join…</p>
        <button
          onClick={() => navigate(`/game/${createdGameId}`)}
          className="rounded-lg bg-slate-700 hover:bg-slate-600 text-slate-100 font-semibold px-5 py-2 text-sm"
        >
          Go to game
        </button>
      </div>
    );
  }

  const anyPending = createGame.isPending || playComputer.isPending || joinGame.isPending;

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
      <h1 className="text-4xl font-black tracking-wide text-yellow-400">Cross Cribbage</h1>
      <p className="text-slate-400 text-sm">Real-time two-player cribbage on a 5×5 board</p>

      {error && <p className="text-red-400 text-xs">{error}</p>}

      <div className="flex flex-col gap-4 w-full max-w-sm">
        <div className="flex gap-2">
          <button
            onClick={() => createGame.mutate()}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-yellow-400 hover:bg-yellow-300 disabled:opacity-50 text-slate-900 font-bold py-3 text-sm transition-colors"
          >
            {createGame.isPending ? "Creating…" : "Start New Game"}
          </button>
          <button
            onClick={() => playComputer.mutate()}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white font-bold py-3 text-sm transition-colors"
          >
            {playComputer.isPending ? "Starting…" : "Play Computer"}
          </button>
        </div>

        <div className="flex items-center gap-2 text-slate-600 text-xs">
          <hr className="flex-1 border-slate-700" /><span>or</span><hr className="flex-1 border-slate-700" />
        </div>

        <div className="flex gap-2">
          <input
            type="text"
            placeholder="Paste Game ID"
            value={joinId}
            onChange={(e) => setJoinId(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && joinGame.mutate()}
            className="flex-1 rounded-lg bg-slate-800 border border-slate-700 text-slate-100 text-sm px-3 py-2 focus:outline-none focus:border-yellow-400"
          />
          <button
            onClick={() => joinGame.mutate()}
            disabled={anyPending || !joinId.trim()}
            className="rounded-lg bg-slate-700 hover:bg-slate-600 disabled:opacity-50 text-slate-100 font-semibold px-4 py-2 text-sm"
          >
            {joinGame.isPending ? "Joining…" : "Join"}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd app/frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Run full test suite**

```bash
bin/rspec
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add app/frontend/components/HomePage.tsx
git commit -m "feat: add Play Computer button to home page"
```

---

> **Note: `GamePage.tsx` requires no changes.** vs_computer games start as `status: "active"` (never `"waiting"`), so the "Waiting for opponent…" screen at `if (game.status === "waiting")` is never reached. The share-game-ID screen on the home page is also bypassed because `playComputer.mutate()` navigates directly to the game page.

---

### Task 9: Smoke test end-to-end

- [ ] **Step 1: Start the dev server**

```bash
bin/dev
```

- [ ] **Step 2: Open the app and click "Play Computer"**

Navigate to `http://localhost:3000`. Click "Play Computer". You should be redirected immediately to a game page (no waiting screen).

- [ ] **Step 3: Verify AI takes its turn within ~2 seconds**

If it's the AI's turn first (50% chance based on crib assignment), the board should update about 2 seconds after load. Play a card yourself and watch the AI respond within 2 seconds.

- [ ] **Step 4: Verify scoring phase**

Fill the board. Both the scoring overlay and the AI's confirmation should complete automatically, and the round should advance.
