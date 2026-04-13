import { describe, it, expect, beforeEach, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import React from "react";
import type { GameState } from "../types/game";
import { useGameAction } from "./useGameAction";

function makeGameState(overrides: Partial<GameState> = {}): GameState {
  return {
    id: "game-1",
    status: "active",
    current_turn: "player1",
    round: 1,
    crib_owner: "player1",
    board: Array.from({ length: 5 }, () => Array(5).fill(null)),
    starter_card: { rank: "5", suit: "♥", id: "5♥" },
    row_scores: [null, null, null, null, null],
    col_scores: [null, null, null, null, null],
    crib_score: null,
    crib_size: { player1: 0, player2: 0 },
    deck_size: { player1: 14, player2: 14 },
    player1_peg: 0,
    player2_peg: 0,
    winner_slot: null,
    player1_confirmed_scoring: false,
    player2_confirmed_scoring: false,
    crib_hand: null,
    vs_computer: false,
    my_slot: "player1",
    my_next_card: { rank: "K", suit: "♠", id: "K♠" },
    ...overrides,
  };
}

let queryClient: QueryClient;

function wrapper({ children }: { children: React.ReactNode }) {
  return React.createElement(QueryClientProvider, { client: queryClient }, children);
}

beforeEach(() => {
  queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
});

describe("useGameAction", () => {
  it("applies optimistic update immediately", async () => {
    const initial = makeGameState();
    queryClient.setQueryData(["game", "game-1"], initial);

    const serverResponse = makeGameState({ current_turn: "player2" });
    const action = vi.fn(() => new Promise<GameState>((resolve) => {
      // Delay resolution to verify optimistic state
      setTimeout(() => resolve(serverResponse), 50);
    }));

    const { result } = renderHook(() => useGameAction("game-1"), { wrapper });

    act(() => {
      result.current.mutate({
        action,
        optimistic: (old) => ({ current_turn: "player2" as const, deck_size: { ...old.deck_size, player1: 13 } }),
      });
    });

    // Optimistic update should be applied before the action resolves
    await waitFor(() => {
      const cached = queryClient.getQueryData<GameState>(["game", "game-1"]);
      expect(cached!.current_turn).toBe("player2");
      expect(cached!.deck_size.player1).toBe(13);
    });
  });

  it("replaces cache with server response on success", async () => {
    const initial = makeGameState();
    queryClient.setQueryData(["game", "game-1"], initial);

    const serverResponse = makeGameState({
      current_turn: "player2",
      deck_size: { player1: 13, player2: 14 },
    });

    const { result } = renderHook(() => useGameAction("game-1"), { wrapper });

    await act(async () => {
      result.current.mutate({
        action: () => Promise.resolve(serverResponse),
        optimistic: () => ({ current_turn: "player2" as const }),
      });
    });

    await waitFor(() => {
      const cached = queryClient.getQueryData<GameState>(["game", "game-1"]);
      expect(cached).toEqual(serverResponse);
    });
  });

  it("rolls back to snapshot on error", async () => {
    const initial = makeGameState({ current_turn: "player1" });
    queryClient.setQueryData(["game", "game-1"], initial);

    const { result } = renderHook(() => useGameAction("game-1"), { wrapper });

    await act(async () => {
      result.current.mutate({
        action: () => Promise.reject(new Error("Not your turn")),
        optimistic: () => ({ current_turn: "player2" as const }),
      });
    });

    await waitFor(() => {
      const cached = queryClient.getQueryData<GameState>(["game", "game-1"]);
      expect(cached!.current_turn).toBe("player1");
    });
  });

  it("works without optimistic update", async () => {
    const initial = makeGameState();
    queryClient.setQueryData(["game", "game-1"], initial);

    const serverResponse = makeGameState({ player1_peg: 5 });
    const { result } = renderHook(() => useGameAction("game-1"), { wrapper });

    await act(async () => {
      result.current.mutate({
        action: () => Promise.resolve(serverResponse),
      });
    });

    await waitFor(() => {
      const cached = queryClient.getQueryData<GameState>(["game", "game-1"]);
      expect(cached!.player1_peg).toBe(5);
    });
  });
});
