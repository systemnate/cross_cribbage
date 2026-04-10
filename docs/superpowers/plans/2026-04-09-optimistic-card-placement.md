# Optimistic Card Placement & Discard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply instant optimistic UI updates when placing a card or discarding to the crib, rolling back on error.

**Architecture:** Extend `useGameAction` to accept an optional `optimistic` updater alongside the action function. React Query's `onMutate`/`onError` lifecycle handles snapshotting and rollback. Call sites in `GamePage` pass the updater for the two actions that benefit; `confirm_round` is unchanged in behavior.

**Tech Stack:** React Query (`useMutation`), TypeScript, React 19

---

### Task 1: Refactor `useGameAction` to support optimistic updates

**Files:**
- Modify: `app/frontend/hooks/useGameAction.ts`

Note: No JS test suite exists in this project, so verification is done by running the dev server and manually testing. The existing error display (`action.error.message`) at the bottom of `GamePage` will surface any rollback.

- [ ] **Step 1: Replace the contents of `useGameAction.ts` with the updated hook**

The mutation variable changes from `() => Promise<GameState>` to a `GameMutation` object. The hook gains `onMutate` (cancel queries, snapshot, apply optimistic update) and `onError` (restore snapshot). `onSuccess` is unchanged.

Full file contents:

```ts
// app/frontend/hooks/useGameAction.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { GameState } from "../types/game";

interface GameMutation {
  action: () => Promise<GameState>;
  optimistic?: (old: GameState) => Partial<GameState>;
}

export function useGameAction(gameId: string | null) {
  const queryClient = useQueryClient();

  return useMutation<GameState, Error, GameMutation, { snapshot: GameState | undefined }>({
    mutationFn: ({ action }) => action(),
    onMutate: async ({ optimistic }) => {
      await queryClient.cancelQueries({ queryKey: ["game", gameId] });
      const snapshot = queryClient.getQueryData<GameState>(["game", gameId]);
      if (optimistic && snapshot) {
        queryClient.setQueryData<GameState>(["game", gameId], {
          ...snapshot,
          ...optimistic(snapshot),
        });
      }
      return { snapshot };
    },
    onError: (_err, _vars, context) => {
      if (gameId && context?.snapshot) {
        queryClient.setQueryData(["game", gameId], context.snapshot);
      }
    },
    onSuccess: (data) => {
      if (gameId) queryClient.setQueryData(["game", gameId], data);
    },
  });
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd /Users/natedalo/Desktop/workspace/cross_cribbage && npx tsc --noEmit
```

Expected: no errors. If errors appear, they will be in `GamePage.tsx` because the call sites still pass `() => Promise<GameState>` — that's fixed in Task 2.

- [ ] **Step 3: Commit**

```bash
git add app/frontend/hooks/useGameAction.ts
git commit -m "feat: extend useGameAction with optimistic updater support"
```

---

### Task 2: Update call sites in `GamePage.tsx`

**Files:**
- Modify: `app/frontend/components/GamePage.tsx:106-116`

- [ ] **Step 1: Replace the three handler functions**

Find these lines in `GamePage.tsx` (currently around line 106–116):

```ts
  function handleCellClick(row: number, col: number) {
    action.mutate(() => api.placeCard(gid, row, col));
  }

  function handleDiscard() {
    action.mutate(() => api.discardToCrib(gid));
  }

  function handleConfirmRound() {
    action.mutate(() => api.confirmRound(gid));
  }
```

Replace with:

```ts
  function handleCellClick(row: number, col: number) {
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
  }

  function handleDiscard() {
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
  }

  function handleConfirmRound() {
    action.mutate({ action: () => api.confirmRound(gid) });
  }
```

- [ ] **Step 2: Verify TypeScript compiles cleanly**

```bash
cd /Users/natedalo/Desktop/workspace/cross_cribbage && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Run the dev server and manually verify**

```bash
bin/dev
```

Test checklist:
1. Start a vs-computer game
2. Discard a card to the crib — the crib count should increment instantly before the server round-trip
3. Place a card on the board — the card should appear in the cell immediately and the board should disable (opponent's turn) before the server responds
4. Confirm the turn indicator flips right away on place

- [ ] **Step 4: Commit**

```bash
git add app/frontend/components/GamePage.tsx
git commit -m "feat: optimistic updates for place_card and discard_to_crib"
```
