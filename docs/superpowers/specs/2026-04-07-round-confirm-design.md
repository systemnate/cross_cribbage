# Round Confirmation Design

**Date:** 2026-04-07  
**Status:** Approved

## Summary

When a round ends and the scoring overlay appears, give players 10 seconds before automatically advancing. If both players click "Ready", advance immediately.

## Backend

### Migration
Add two boolean columns to the `games` table:
- `player1_confirmed_scoring` — boolean, default `false`, not null
- `player2_confirmed_scoring` — boolean, default `false`, not null

### Game Model (`app/models/game.rb`)
- Add `confirm_scoring!(slot)` — raises `Game::Error` unless `status == "scoring"`, sets `"#{slot}_confirmed_scoring"` to `true`, saves.
- Add `both_scoring_confirmed?` — returns `player1_confirmed_scoring && player2_confirmed_scoring`.
- `advance_round!` calls `setup_round!` which already resets round state — add reset of both flags there (`self.player1_confirmed_scoring = false; self.player2_confirmed_scoring = false`).

### Controller (`app/controllers/api/games_controller.rb`)
- Move `AdvanceRoundJob` enqueueing out of `game_action` helper into `place_card` action only. Enqueue with `wait: 10.seconds` when `@game.status == "scoring"` after the board fills.
- Add `confirm_round` to `GAME_ACTIONS`.
- New `confirm_round` action:
  ```ruby
  def confirm_round
    game_action do
      @game.confirm_scoring!(current_slot)
      @game.advance_round! if @game.both_scoring_confirmed?
    end
  end
  ```
  No job is enqueued here — the 10s job was already enqueued when scoring started.

### Routes (`config/routes.rb`)
Add `post :confirm_round` as a member route alongside `place_card` and `discard_to_crib`.

### Serialization
Add `player1_confirmed_scoring` and `player2_confirmed_scoring` to:
- `Game#serialize_for` (HTTP response)
- `GameChannel.broadcast_game_state` (ActionCable broadcast)

Both players need these fields to show real-time confirmation status.

## Frontend

### Types (`app/frontend/types/game.ts`)
Add to `GameState`:
```ts
player1_confirmed_scoring: boolean;
player2_confirmed_scoring: boolean;
```
`GameChannelMessage` inherits these automatically via its `Omit` definition.

### API (`app/frontend/lib/api.ts`)
Add:
```ts
confirmRound: (id: string): Promise<GameState> =>
  request("POST", `/games/${id}/confirm_round`),
```

### GamePage (`app/frontend/components/GamePage.tsx`)
Add `handleConfirmRound` that calls `action.mutate(() => api.confirmRound(gid))`. Pass it and `action.isPending` to `ScoringOverlay`.

### ScoringOverlay (`app/frontend/components/ScoringOverlay.tsx`)
- Change countdown initial value from `3` to `10`.
- Add props: `onConfirm: () => void`, `isConfirmPending: boolean`.
- Derive `iConfirmed` from `game[mySlot + "_confirmed_scoring"]` — hide or disable the button once confirmed.
- Derive `opponentConfirmed` from the other slot's flag.
- Show confirmation status row: e.g. "You: Ready ✓ | Opponent: waiting…" or "Both ready!"
- Button: "Ready for next round" — disabled when `iConfirmed || isConfirmPending`.

## Error Handling
- `confirm_scoring!` raises `Game::Error` if called outside scoring state — controller's `game_action` rescue handles this and returns a 422.
- Double-confirm by same player is idempotent (flag already `true`, save is a no-op in effect).

## Testing
- Unit: `Game#confirm_scoring!` sets flag; `both_scoring_confirmed?` truth table; `advance_round!` resets flags.
- Controller: `POST confirm_round` sets flag and broadcasts; both confirmed triggers immediate advance; non-scoring state returns error.
- Frontend: button disables after click; opponent-confirmed state shows correctly; countdown starts at 10.
