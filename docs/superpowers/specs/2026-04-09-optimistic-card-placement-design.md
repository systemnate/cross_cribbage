# Optimistic Card Placement & Discard

**Date:** 2026-04-09
**Status:** Approved

## Problem

On Fly.io, placing a card or discarding to the crib has a ~0.5s round-trip delay before the UI reflects the action. The goal is to make these feel instant by applying an optimistic update immediately, then replacing it with server truth on success or rolling back on error.

## Approach

Extend `useGameAction` with an optional `optimistic` updater function per mutation call. React Query's `onMutate`/`onError` lifecycle handles snapshot/rollback automatically.

## Hook Changes (`useGameAction.ts`)

Change the mutation variable type from:
```ts
() => Promise<GameState>
```
to:
```ts
{ action: () => Promise<GameState>; optimistic?: (old: GameState) => Partial<GameState> }
```

Lifecycle additions:
- **`onMutate`**: cancel in-flight refetches for `["game", gameId]`, snapshot the current cache value, apply `optimistic(old)` if provided via `queryClient.setQueryData`, return `{ snapshot }` as rollback context.
- **`onError`**: restore snapshot via `queryClient.setQueryData`.
- **`onSuccess`**: unchanged — server response replaces cache (server is always authoritative).

## Call Site Changes (`GamePage.tsx`)

### `handleCellClick(row, col)`
```ts
action.mutate({
  action: () => api.placeCard(gid, row, col),
  optimistic: (old) => {
    if (!old.my_next_card) return {};
    const board = old.board.map(r => [...r]);
    board[row][col] = old.my_next_card;
    const mySlot = old.my_slot!;
    const oppSlot = mySlot === "player1" ? "player2" : "player1";
    return {
      board,
      my_next_card: null,
      deck_size: { ...old.deck_size, [mySlot]: old.deck_size[mySlot] - 1 },
      current_turn: oppSlot,
    };
  },
});
```

### `handleDiscard()`
```ts
action.mutate({
  action: () => api.discardToCrib(gid),
  optimistic: (old) => {
    if (!old.my_next_card) return {};
    const mySlot = old.my_slot!;
    return {
      my_next_card: null,
      deck_size: { ...old.deck_size, [mySlot]: old.deck_size[mySlot] - 1 },
      crib_size: { ...old.crib_size, [mySlot]: old.crib_size[mySlot] + 1 },
    };
  },
});
```

### `handleConfirmRound()`
```ts
action.mutate({ action: () => api.confirmRound(gid) });
```

## Error Handling & Rollback

On network error or server rejection, `onError` restores the pre-click snapshot. The existing `action.error.message` display in `GamePage` surfaces the error. No additional UI changes needed.

## Edge Cases

- **`my_next_card` is null**: Both optimistic functions guard with an early `return {}`, so no stale state is applied. Shouldn't occur in normal flow.
- **ActionCable broadcast during optimistic window**: `useGameChannel` overwrites the cache with the broadcast payload, which is server-authoritative. This is correct behavior — the broadcast represents real state.
- **Double-click prevention**: Setting `current_turn = oppSlot` immediately disables the board (`isMyTurn` becomes false), preventing a second click before the server responds.

## Files Changed

- `app/frontend/hooks/useGameAction.ts` — mutation variable type + lifecycle hooks
- `app/frontend/components/GamePage.tsx` — updated `handleCellClick`, `handleDiscard`, `handleConfirmRound` call sites
