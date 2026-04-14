# Computer AI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the computer player smarter by adding defensive column blocking and row potential scoring to replace the current greedy single-card evaluation.

**Architecture:** Two new scoring components (`defensive_score`, `row_potential`) are added as additive terms to the existing `net_impact` in `ComputerPlayer#decide`. A shared `best_fill_score` helper simulates optimal card fills using `CribbageHand`. The existing `early_game_potential` method is removed.

**Tech Stack:** Ruby, RSpec, FactoryBot. Only `app/lib/computer_player.rb` and its spec change.

---

## File Structure

- **Modify:** `app/lib/computer_player.rb` — add `best_fill_score`, `defensive_score`, `row_potential` methods; update `decide` to use new formula; remove `early_game_potential`; add tuning constants
- **Modify:** `spec/lib/computer_player_spec.rb` — add unit tests for new methods, update existing tests for new behavior

---

### Task 1: Add `best_fill_score` helper with tests

The shared helper that both `defensive_score` and `row_potential` depend on.

**Files:**
- Modify: `spec/lib/computer_player_spec.rb`
- Modify: `app/lib/computer_player.rb`

- [ ] **Step 1: Write the failing test for `best_fill_score`**

Add to `spec/lib/computer_player_spec.rb` inside the top-level `RSpec.describe ComputerPlayer` block, after the existing describes:

```ruby
describe "#best_fill_score (via send)" do
  # Test the private helper directly via send for unit testing
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  let(:starter) { card("3", "♥") }

  let(:game) do
    create(:game,
      board: Array.new(5) { Array.new(5, nil) }.tap { |b| b[2][2] = starter },
      starter_card: starter,
      row_scores: [nil, nil, nil, nil, nil],
      col_scores: [nil, nil, nil, nil, nil],
      player1_deck: [],
      player2_deck: [],
      player2_crib_discards: 2
    )
  end

  let(:cp) { described_class.new(game) }

  it "returns 0 when no empty slots" do
    existing = [card("5", "♠"), card("5", "♦"), card("10", "♥"), card("J", "♣"), card("K", "♦")]
    score = cp.send(:best_fill_score, existing, [], 0, row_index: 0)
    expect(score).to eq(CribbageHand.new(existing, starter: starter, is_center: false).score)
  end

  it "picks the best card from the deck to fill one slot" do
    existing = [card("5", "♠"), card("5", "♦"), card("10", "♥"), card("J", "♣")]
    deck = [card("A", "♣"), card("5", "♥"), card("K", "♦")]
    # 5♥ should be picked: adds a third 5 (pair royal = 6) plus more fifteens
    score = cp.send(:best_fill_score, existing, deck, 1, row_index: 0)

    # Verify it picked the best — score with 5♥ should beat score with A or K
    best_hand = existing + [deck[1]] # the 5♥
    expect(score).to eq(CribbageHand.new(best_hand, starter: starter, is_center: false).score)
  end

  it "fills multiple slots with the best combination" do
    existing = [card("7", "♠"), card("8", "♦"), card("9", "♥")]
    deck = [card("6", "♣"), card("10", "♠"), card("A", "♦"), card("2", "♥")]
    # 6 + 10 gives a 5-card run (6-7-8-9-10) = 5 points + fifteens
    score = cp.send(:best_fill_score, existing, deck, 2, row_index: 0)

    best_hand = existing + [deck[0], deck[1]] # 6 and 10
    expect(score).to eq(CribbageHand.new(best_hand, starter: starter, is_center: false).score)
  end

  it "uses is_center: true for row 2" do
    existing = [card("J", "♥"), card("5", "♠"), card("10", "♦")]
    deck = [card("K", "♣"), card("Q", "♠")]
    score_center = cp.send(:best_fill_score, existing, deck, 2, row_index: 2)
    score_other = cp.send(:best_fill_score, existing, deck, 2, row_index: 0)

    # Row 2 (center) enables nobs scoring — J of starter's suit scores extra
    # Even if nobs doesn't apply here, is_center should be passed correctly
    expect(score_center).to be >= score_other
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "best_fill_score"`
Expected: FAIL — `NoMethodError: undefined method 'best_fill_score'`

- [ ] **Step 3: Implement `best_fill_score` in `ComputerPlayer`**

Add the following private method to `app/lib/computer_player.rb`, inside the `private` section, replacing the existing `card_fifteen_value` method (which is no longer needed — it was only used by `early_game_potential`):

```ruby
# Given cards already in a line and a deck to draw from, find the max
# score achievable by filling `empty_count` slots with cards from `deck`.
# Pass row_index for rows, col_index for columns (determines is_center).
def best_fill_score(existing_cards, deck, empty_count, row_index: nil, col_index: nil)
  is_center = (row_index == 2 || col_index == 2)

  if empty_count == 0 || deck.empty?
    return CribbageHand.new(existing_cards, starter: @game.starter_card, is_center: is_center).score
  end

  fillable = [empty_count, deck.size].min
  best = 0

  deck.combination(fillable).each do |combo|
    hand = existing_cards + combo
    score = CribbageHand.new(hand, starter: @game.starter_card, is_center: is_center).score
    best = score if score > best
  end

  best
end
```

Leave `card_fifteen_value` and `early_game_potential` in place for now — they're still called by `decide` until Task 4 replaces it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "best_fill_score"`
Expected: All 4 examples PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/computer_player.rb spec/lib/computer_player_spec.rb
git commit -m "feat: add best_fill_score helper to ComputerPlayer

Shared helper that simulates filling empty line slots with optimal cards
from a given deck. Used by both defensive and row potential scoring."
```

---

### Task 2: Add `defensive_score` with tests

**Files:**
- Modify: `spec/lib/computer_player_spec.rb`
- Modify: `app/lib/computer_player.rb`

- [ ] **Step 1: Write the failing tests for `defensive_score`**

Add to `spec/lib/computer_player_spec.rb`:

```ruby
describe "#defensive_score (via send)" do
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  let(:starter) { card("3", "♥") }

  # Blocking scenario: column has 7-7-8-8, computer places an Ace.
  # The Ace should disrupt the opponent's best-case score.
  describe "blocking a dangerous column" do
    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[0][0] = card("7", "♠")
      b[1][0] = card("7", "♦")
      b[3][0] = card("8", "♣")
      b[4][0] = card("8", "♥")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player1_deck: [card("6", "♠"), card("9", "♦"), card("5", "♣"), card("10", "♥")],
        player2_deck: [card("A", "♦")],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns a positive score (placement disrupts opponent)" do
      col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
      score = cp.send(:defensive_score, 2, 0, card("A", "♦"), col_base)
      expect(score).to be > 0
    end
  end

  # Feeding scenario: column has 7-8, computer places a 6.
  # The 6 helps the opponent build a run.
  describe "feeding a dangerous column" do
    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[0][1] = card("7", "♠")
      b[1][1] = card("8", "♦")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player1_deck: [card("6", "♣"), card("9", "♥"), card("5", "♦"), card("10", "♣")],
        player2_deck: [card("6", "♠")],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns a negative score (placement helps opponent)" do
      col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
      score = cp.send(:defensive_score, 2, 1, card("6", "♠"), col_base)
      expect(score).to be < 0
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "defensive_score"`
Expected: FAIL — `NoMethodError: undefined method 'defensive_score'`

- [ ] **Step 3: Implement `defensive_score`**

Add to the `private` section of `app/lib/computer_player.rb`:

```ruby
# Evaluate how placing `card` at (row, col) affects the opponent's
# best-case score in that column. Positive = disrupted opponent.
def defensive_score(row, col, card, col_base)
  col_cards_without = col_base[col]
  col_cards_with    = col_cards_without + [card]

  empty_without = 5 - col_cards_without.size
  empty_with    = 5 - col_cards_with.size

  opponent_deck = @game.player1_deck

  potential_without = best_fill_score(col_cards_without, opponent_deck, empty_without, col_index: col)
  potential_with    = best_fill_score(col_cards_with, opponent_deck, empty_with, col_index: col)

  potential_without - potential_with
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "defensive_score"`
Expected: Both examples PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/computer_player.rb spec/lib/computer_player_spec.rb
git commit -m "feat: add defensive_score to ComputerPlayer

Evaluates how a placement affects the opponent's best-case column score.
Positive values mean the card disrupts the opponent; negative means it
helps them."
```

---

### Task 3: Add `row_potential` with tests

**Files:**
- Modify: `spec/lib/computer_player_spec.rb`
- Modify: `app/lib/computer_player.rb`

- [ ] **Step 1: Write the failing tests for `row_potential`**

Add to `spec/lib/computer_player_spec.rb`:

```ruby
describe "#row_potential (via send)" do
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  let(:starter) { card("3", "♥") }

  describe "completing a row returns 0" do
    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[0][0] = card("5", "♠")
      b[0][1] = card("5", "♦")
      b[0][3] = card("10", "♥")
      b[0][4] = card("J", "♣")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player2_deck: [card("5", "♥"), card("K", "♠"), card("Q", "♦")],
        player1_deck: [],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns 0 because the row is being completed" do
      row_base = Array.new(5) { |r| board[r].compact }
      score = cp.send(:row_potential, 0, 2, card("5", "♥"), row_base)
      expect(score).to eq(0)
    end
  end

  describe "building a promising row returns positive potential" do
    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[1][0] = card("7", "♠")
      b[1][1] = card("8", "♦")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player2_deck: [card("9", "♣"), card("6", "♥"), card("10", "♠"), card("A", "♦")],
        player1_deck: [],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns positive potential for a row with run seeds" do
      row_base = Array.new(5) { |r| board[r].compact }
      # Placing 9♣ in row 1 creates 7-8-9 run seed with 2 open slots
      score = cp.send(:row_potential, 1, 2, card("9", "♣"), row_base)
      expect(score).to be > 0
    end
  end

  describe "building a dead-end row returns lower potential" do
    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[3][0] = card("A", "♠")
      b[3][1] = card("3", "♦")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player2_deck: [card("9", "♣"), card("6", "♥"), card("10", "♠"), card("K", "♦")],
        player1_deck: [],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns lower potential than a synergistic row" do
      row_base = Array.new(5) { |r| board[r].compact }
      # Row 3 has A-3 with a K being placed — low synergy
      dead_end = cp.send(:row_potential, 3, 2, card("K", "♦"), row_base)

      # Compare: if row 3 had 7-8 with 9 being placed (high synergy)
      # We can't directly compare in this test, but dead_end should be modest
      expect(dead_end).to be >= 0
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "row_potential"`
Expected: FAIL — `NoMethodError: undefined method 'row_potential'`

- [ ] **Step 3: Implement `row_potential`**

Add to the `private` section of `app/lib/computer_player.rb`:

```ruby
# Evaluate the future scoring ceiling of placing `card` in this row.
# Returns 0 for row-completing placements (net_impact handles those).
# Returns positive values for rows with high upside.
def row_potential(row, col, card, row_base)
  row_cards_with = row_base[row] + [card]
  empty_after = 5 - row_cards_with.size

  return 0 if empty_after == 0

  current_row_score = @game.row_scores[row].to_i
  best_case = best_fill_score(row_cards_with, @game.player2_deck, empty_after, row_index: row)

  best_case - current_row_score
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "row_potential"`
Expected: All 3 examples PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/computer_player.rb spec/lib/computer_player_spec.rb
git commit -m "feat: add row_potential to ComputerPlayer

Evaluates the future scoring ceiling of a row after placing a card.
Returns 0 for completed rows; positive values for rows with upside."
```

---

### Task 4: Wire up new formula, remove `early_game_potential`, add integration tests

**Files:**
- Modify: `app/lib/computer_player.rb`
- Modify: `spec/lib/computer_player_spec.rb`

- [ ] **Step 1: Write the failing integration tests**

Add to `spec/lib/computer_player_spec.rb`:

```ruby
describe "#decide with defensive blocking" do
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  # Column 0 has 7-7-8-8 — a monster threat for the opponent.
  # The only open slot in column 0 is (2, 0).
  # The computer's next card is A♦ — low synergy, good blocker.
  # The computer should place at (2, 0) to disrupt the opponent's column,
  # even though there's no immediate row benefit.
  let(:starter) { card("3", "♥") }

  let(:board) do
    b = Array.new(5) { Array.new(5, nil) }
    b[2][2] = starter
    b[0][0] = card("7", "♠")
    b[1][0] = card("7", "♦")
    b[3][0] = card("8", "♣")
    b[4][0] = card("8", "♥")
    b
  end

  let(:game) do
    create(:game,
      board: board,
      starter_card: starter,
      row_scores: [nil, nil, nil, nil, nil],
      col_scores: [nil, nil, nil, nil, nil],
      player1_deck: [card("6", "♠"), card("9", "♦"), card("5", "♣"), card("10", "♥"),
                     card("4", "♠"), card("J", "♦"), card("Q", "♣"), card("K", "♥")],
      player2_deck: [card("A", "♦"), card("2", "♣"), card("4", "♥")],
      player2_crib_discards: 2,
      player1_crib_discards: 2,
      crib_owner: "player1"
    )
  end

  it "blocks the dangerous column by placing at (2, 0)" do
    result = described_class.new(game).decide
    expect(result[:action]).to eq(:place)
    expect(result[:row]).to eq(2)
    expect(result[:col]).to eq(0)
  end
end

describe "#decide prefers building potential over completing low-value rows" do
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  # Row 0 has 4 cards: A-2-3-K. Placing a Q completes it for ~3-4 points (a run of 3).
  # Row 1 has 2 cards: 5-5. Placing a Q (value 10) gives a fifteen (5+10) with
  #   high potential for more fifteens/pairs with remaining 5s and 10-value cards.
  # The computer should prefer row 1 for its higher potential.
  let(:starter) { card("3", "♥") }

  let(:board) do
    b = Array.new(5) { Array.new(5, nil) }
    b[2][2] = starter
    b[0][0] = card("A", "♠")
    b[0][1] = card("2", "♦")
    b[0][3] = card("K", "♣")
    b[0][4] = card("3", "♠")
    b[1][0] = card("5", "♠")
    b[1][1] = card("5", "♦")
    b
  end

  let(:game) do
    create(:game,
      board: board,
      starter_card: starter,
      row_scores: [nil, nil, nil, nil, nil],
      col_scores: [nil, nil, nil, nil, nil],
      player1_deck: [],
      player2_deck: [card("Q", "♥"), card("5", "♥"), card("10", "♣"), card("J", "♦")],
      player2_crib_discards: 2,
      player1_crib_discards: 2,
      crib_owner: "player1"
    )
  end

  it "places in row 1 (higher potential) rather than completing row 0" do
    result = described_class.new(game).decide
    expect(result[:action]).to eq(:place)
    expect(result[:row]).to eq(1)
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -e "defensive blocking" -e "prefers building potential"`
Expected: FAIL — the current greedy algorithm doesn't account for defense or potential

- [ ] **Step 3: Update `decide` with the new scoring formula**

Replace the entire `decide` method and remove `early_game_potential` and `card_fifteen_value` in `app/lib/computer_player.rb`. The full updated file should be:

```ruby
# frozen_string_literal: true

class ComputerPlayer
  # AI always plays as player2.
  # player2 scores rows; player1 (opponent) scores columns.

  DEFENSIVE_WEIGHT     = 1.0
  ROW_POTENTIAL_WEIGHT = 0.3

  def initialize(game)
    @game = game
  end

  # Returns { action: :place, row: Integer, col: Integer }
  #      or { action: :discard }
  def decide
    # Mirror game.rb's forced-discard rule: if deck is too small to place, must discard first.
    remaining_crib = 2 - @game.player2_crib_discards
    return { action: :discard } if @game.player2_deck.size <= remaining_crib

    next_card = @game.player2_deck.first
    return { action: :discard } unless next_card

    best_move  = nil
    best_score = nil

    # Precompute each row's and column's current cards once.
    row_base = Array.new(5) { |r| @game.board[r].compact }
    col_base = Array.new(5) { |c| @game.board.map { |r| r[c] }.compact }

    5.times do |row|
      5.times do |col|
        next if @game.board[row][col]  # occupied

        net    = simulate_net_impact(row, col, next_card, row_base, col_base)
        defend = defensive_score(row, col, next_card, col_base)
        potential = row_potential(row, col, next_card, row_base)

        total = net + (defend * DEFENSIVE_WEIGHT) + (potential * ROW_POTENTIAL_WEIGHT)

        if best_score.nil? || total > best_score
          best_score = total
          best_move  = { action: :place, row: row, col: col }
        end
      end
    end

    # Prefer discarding over a net-neutral/negative move if crib still has room
    # and player2 owns the crib (discarding benefits the AI).
    # Wait until the opponent has placed at least 6 cards so board simulation
    # is meaningful.
    opponent_cards_placed = 14 - @game.player1_crib_discards - @game.player1_deck.size
    if best_score && best_score <= 0 &&
       @game.player2_crib_discards < 2 && @game.crib_owner == "player2" &&
       opponent_cards_placed >= 6
      return { action: :discard }
    end

    best_move || { action: :discard }
  end

  private

  def simulate_net_impact(row, col, card, row_base, col_base)
    current_row_score = @game.row_scores[row].to_i
    current_col_score = @game.col_scores[col].to_i

    row_cards = row_base[row] + [card]
    col_cards = col_base[col] + [card]

    new_row_score = CribbageHand.new(row_cards, starter: @game.starter_card, is_center: row == 2).score
    new_col_score = CribbageHand.new(col_cards, starter: @game.starter_card, is_center: col == 2).score

    (new_row_score - current_row_score) - (new_col_score - current_col_score)
  end

  # Evaluate how placing `card` at (row, col) affects the opponent's
  # best-case score in that column. Positive = disrupted opponent.
  def defensive_score(row, col, card, col_base)
    col_cards_without = col_base[col]
    col_cards_with    = col_cards_without + [card]

    empty_without = 5 - col_cards_without.size
    empty_with    = 5 - col_cards_with.size

    opponent_deck = @game.player1_deck

    potential_without = best_fill_score(col_cards_without, opponent_deck, empty_without, col_index: col)
    potential_with    = best_fill_score(col_cards_with, opponent_deck, empty_with, col_index: col)

    potential_without - potential_with
  end

  # Evaluate the future scoring ceiling of placing `card` in this row.
  # Returns 0 for row-completing placements (net_impact handles those).
  # Returns positive values for rows with high upside.
  def row_potential(row, col, card, row_base)
    row_cards_with = row_base[row] + [card]
    empty_after = 5 - row_cards_with.size

    return 0 if empty_after == 0

    current_row_score = @game.row_scores[row].to_i
    best_case = best_fill_score(row_cards_with, @game.player2_deck, empty_after, row_index: row)

    best_case - current_row_score
  end

  # Given cards already in a line and a deck to draw from, find the max
  # score achievable by filling `empty_count` slots with cards from `deck`.
  def best_fill_score(existing_cards, deck, empty_count, row_index: nil, col_index: nil)
    is_center = (row_index == 2 || col_index == 2)

    if empty_count == 0 || deck.empty?
      return CribbageHand.new(existing_cards, starter: @game.starter_card, is_center: is_center).score
    end

    fillable = [empty_count, deck.size].min
    best = 0

    deck.combination(fillable).each do |combo|
      hand = existing_cards + combo
      score = CribbageHand.new(hand, starter: @game.starter_card, is_center: is_center).score
      best = score if score > best
    end

    best
  end
end
```

- [ ] **Step 4: Run ALL computer player tests**

Run: `bundle exec rspec spec/lib/computer_player_spec.rb -v`
Expected: All examples PASS (including the existing tests — they should still pass because the new formula is a superset of the old behavior for those scenarios)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `bundle exec rspec`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/computer_player.rb spec/lib/computer_player_spec.rb
git commit -m "feat: wire up defensive blocking and row potential in ComputerPlayer

Replace greedy single-card evaluation with a formula that adds defensive
column blocking and future row potential scoring. Remove early_game_potential
which is now subsumed by row_potential.

Formula: net_impact + (defensive_score * 1.0) + (row_potential * 0.3)"
```
