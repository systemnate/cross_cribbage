# Computer AI Improvements: Defensive Blocking & Row Potential

## Problem

The computer player uses a greedy single-card evaluation that only considers immediate score delta (`net_impact`). This leads to two observable weaknesses:

1. **Completes rows too eagerly for low points.** Early in the game, the computer fills rows that score 2-4 points instead of building toward high-value hands. The `early_game_potential` tiebreaker is too weak (only fires on ties) and too shallow.

2. **No defensive awareness.** The computer ignores opponent column composition. A column forming 7-7-8-8 gets no special treatment — the computer won't block it and may even feed it useful cards. The opponent can steer cards into high-potential columns unchallenged.

## Design

### Scoring Formula

Current:

```
score = net_impact   (early_game_potential as tiebreaker)
```

New:

```
score = net_impact + (defensive_score * DEFENSIVE_WEIGHT) + (row_potential * ROW_POTENTIAL_WEIGHT)
```

All three terms are evaluated per candidate cell. `net_impact` stays as-is. The two new terms are additive adjustments. `early_game_potential` is removed — `row_potential` subsumes it.

### Defensive Blocking

For each candidate cell at `(row, col)`, evaluate how the placement affects the opponent's best-case score in that column.

1. Take the column's current cards.
2. From the opponent's remaining deck, find the combination of N cards (N = remaining empty slots) that maximizes the column score.
3. Compute `potential_without` = best possible column score without the computer's card.
4. Compute `potential_with` = best possible column score with the computer's card placed.
5. `defensive_score = potential_without - potential_with`

A positive value means the placement disrupted the opponent (e.g., dropping an Ace into a 7-7-8-8 column). A negative value means the placement helped the opponent (e.g., adding a 6 to a 7-8 column).

Best-case (not average) is used because the opponent can intentionally steer cards into high-potential columns.

### Row Potential

For each candidate cell at `(row, col)`, evaluate the future scoring ceiling of the row.

1. Take the row's current cards plus the candidate card.
2. Fill remaining empty slots with the best combination of cards from the computer's remaining deck.
3. `best_case_row_score` = score of the fully filled row.

Scoring:
- If the placement **completes** the row (fills the 5th slot): `row_potential = 0`. The row is locked in and `net_impact` already captures the actual points.
- If the placement does **not** complete the row: `row_potential = best_case_row_score - current_row_score`. This is the upside — how much better this row could get.

The weight constant scales this down so speculative future value doesn't dominate concrete immediate gains.

### Shared Helper

Both components need the same operation: "given these cards in a line and this deck, what's the best score if we fill the remaining slots optimally?"

```ruby
def best_fill_score(existing_cards, deck, empty_count, row_index: nil, col_index: nil)
```

- Iterates over combinations of `empty_count` cards from `deck`
- Scores each combination using `CribbageHand`
- Returns the maximum score

With at most 4 empty slots and decks of ~12 cards, the worst case is C(12,4) = 495 combinations per line, evaluated up to 25 times per move. Well within performance budget for a background job.

### Tuning Constants

```ruby
DEFENSIVE_WEIGHT      = 1.0
ROW_POTENTIAL_WEIGHT  = 0.3
```

**`DEFENSIVE_WEIGHT = 1.0`** — Blocking and scoring are treated equally. "Deny them 4 points" is valued the same as "gain 4 points."
- Lower (e.g., 0.5): computer prioritizes own scoring, needs to block 6 to justify sacrificing 3.
- Higher (e.g., 1.5): computer over-indexes on defense, may play too passively.

**`ROW_POTENTIAL_WEIGHT = 0.3`** — Future row potential is discounted relative to immediate points.
- Lower (e.g., 0.1): greedy play, takes immediate points, closer to current behavior.
- Higher (e.g., 0.6): speculative play, sacrifices immediate points for future upside.
- At 0.3: a completed row scoring 8 now beats a row with 20 potential (20 * 0.3 = 6), but not one with 30 potential (30 * 0.3 = 9).

These are starting points to be adjusted via playtesting.

## Scope

### Changes

- `app/lib/computer_player.rb` — new scoring formula, new methods (`defensive_score`, `row_potential`, `best_fill_score`), remove `early_game_potential`
- New/updated RSpec tests for the computer player

### No Changes

- `app/lib/cribbage_hand.rb` — unchanged, used as-is for scoring simulations
- `app/models/game.rb` — unchanged
- Frontend — unchanged
- API — unchanged

## Testing

- Unit tests for `best_fill_score` with known card sets
- Unit tests for `defensive_score`: verify blocking a dangerous column produces positive score, feeding a column produces negative
- Unit tests for `row_potential`: verify completed rows return 0, promising rows return positive values
- Integration test for `decide`: set up a board with a clear defensive blocking opportunity and verify the computer blocks
- Integration test for `decide`: set up a board where completing a low-value row competes with building a high-potential row, verify it chooses potential
