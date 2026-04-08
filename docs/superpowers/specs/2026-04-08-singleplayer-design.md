# Single-Player (vs Computer) Mode

**Date:** 2026-04-08  
**Status:** Approved

## Overview

Add a "Play Computer" button to the home screen so a player can start a game immediately against a server-side AI opponent. The AI plays as player2, runs in a background job, and uses a greedy one-move lookahead to decide where to place each card.

---

## Data Model

One new boolean column on `games`: `vs_computer` (default `false`).

- When `true`, player2 is the AI. Its token (`player2_token`) is generated at game creation — never shared.
- `serialize_for` gains one new field: `vs_computer: boolean`.
- No new tables or models.

---

## Game Creation Flow

`POST /api/games` accepts an optional `{ vs_computer: true }` param.

When `vs_computer: true`:
1. Generate both `player1_token` and `player2_token` immediately.
2. Call `game.deal!` — game starts as `"active"`, skipping `"waiting"` entirely.
3. Return `{ game_id, token }` where `token` is the human's (player1) token.

The existing `POST /api/games/:id/join` endpoint is unchanged.

---

## ComputerMoveJob

A new `ComputerMoveJob` is enqueued with a 2-second delay whenever it becomes the AI's turn.

**Trigger points — move job** (end of `save!` in `game.rb`):
- `deal!` — AI may go first if player1 owns the crib
- `place_card!`
- `discard_to_crib!`
- `advance_round!`

Condition: `vs_computer? && current_turn == "player2" && status == "active"`

**Trigger points — confirm job** (also end of `save!`):
- `place_card!` — may transition status to `"scoring"`

Condition: `vs_computer? && status == "scoring" && !player2_confirmed_scoring`

**Move job logic:**
1. Reload game from DB.
2. Guard: return early if not `active`, not player2's turn, or game finished.
3. Decide: discard or place (see AI Logic below).
4. Call `game.place_card!("player2", row, col)` or `game.discard_to_crib!("player2")`.
5. The existing `GameChannel` broadcast fires automatically — no extra wiring needed.

**Confirm job logic:**
1. Reload game from DB.
2. Guard: return early if not `scoring` or already confirmed.
3. Call `game.confirm_scoring!("player2")`.
4. The existing `AdvanceRoundJob` handles advancing the round once both players confirm.

---

## AI Logic

Implemented as a `ComputerPlayer` class (or module) to keep it isolated from `game.rb`.

**Input:** current game state (board, decks, scores, crib discards, starter card)  
**Output:** `{ action: :place, row:, col: }` or `{ action: :discard }`

**Algorithm:**

1. The AI's next card is `player2_deck.first` (known server-side).
2. For each empty cell `(row, col)` on the board:
   - Simulate placing the card: compute `delta_row` and `delta_col` using `CribbageHand`.
   - AI scores **rows** (player2 rule); opponent scores **columns** (player1 rule).
   - `net_impact = delta_row - delta_col`
3. Find the cell with the highest `net_impact`.
4. If `best_net_impact <= 0` and `player2_crib_discards < 2` → **discard**.
5. Otherwise → **place** at the best cell.

Scoring simulation reuses `CribbageHand` directly — no duplication.

---

## Frontend Changes

**`HomePage.tsx`:** Add "Play Computer" button next to "Start New Game" on the same line. Calls `api.createGame({ vs_computer: true })`, stores credentials, navigates to `/game/:id`.

**`api.ts`:** `createGame` accepts optional `{ vs_computer?: boolean }`.

**`GamePage.tsx`:** When `game.vs_computer === true`, suppress the "Waiting for opponent…" state and any share-game-ID UI.

**`types/game.ts`:** Add `vs_computer: boolean` to `GameState`.

The board, scoring overlay, peg board, and all game interactions are unchanged.

---

## What Does Not Change

- `POST /api/games/:id/join` — untouched
- `GameChannel` WebSocket broadcasts — no changes
- Game page routing or state management
- All existing two-player functionality
