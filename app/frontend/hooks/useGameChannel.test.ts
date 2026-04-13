import { describe, it, expect, beforeEach, vi } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import React from "react";
import type { GameState, GameChannelMessage } from "../types/game";

// Mock ActionCable — capture the `received` callback so tests can simulate broadcasts
type ReceivedFn = (data: GameChannelMessage) => void;
let receivedCallback: ReceivedFn | null = null;
const mockUnsubscribe = vi.fn();
const mockCreate = vi.fn((_params: unknown, callbacks: { received: ReceivedFn }) => {
  receivedCallback = callbacks.received;
  return { unsubscribe: mockUnsubscribe };
});

vi.mock("../lib/cable", () => ({
  getConsumer: () => ({
    subscriptions: { create: mockCreate },
  }),
}));

const { useGameChannel } = await import("./useGameChannel");

function makeCard(rank: string, suit: string) {
  return { rank, suit, id: `${rank}${suit}` };
}

const emptyBoard: (null)[][] = Array.from({ length: 5 }, () => Array(5).fill(null));

function makeGameState(overrides: Partial<GameState> = {}): GameState {
  return {
    id: "game-1",
    status: "active",
    current_turn: "player1",
    round: 1,
    crib_owner: "player1",
    board: emptyBoard,
    starter_card: makeCard("5", "♥"),
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
    my_next_card: makeCard("K", "♠"),
    ...overrides,
  };
}

function makeBroadcast(overrides: Partial<GameChannelMessage> = {}): GameChannelMessage {
  return {
    type: "game_state",
    status: "active",
    current_turn: "player2",
    round: 1,
    crib_owner: "player1",
    board: emptyBoard,
    starter_card: makeCard("5", "♥"),
    row_scores: [null, null, null, null, null],
    col_scores: [null, null, null, null, null],
    crib_score: null,
    crib_size: { player1: 0, player2: 0 },
    deck_size: { player1: 13, player2: 14 },
    player1_peg: 0,
    player2_peg: 0,
    winner_slot: null,
    player1_confirmed_scoring: false,
    player2_confirmed_scoring: false,
    crib_hand: null,
    vs_computer: false,
    player1_next_card: makeCard("Q", "♠"),
    player2_next_card: makeCard("3", "♦"),
    ...overrides,
  };
}

let queryClient: QueryClient;

function wrapper({ children }: { children: React.ReactNode }) {
  return React.createElement(QueryClientProvider, { client: queryClient }, children);
}

function simulateBroadcast(data: GameChannelMessage) {
  if (!receivedCallback) throw new Error("No subscription created yet");
  receivedCallback(data);
}

beforeEach(() => {
  queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  receivedCallback = null;
  mockCreate.mockClear();
  mockUnsubscribe.mockClear();
});

describe("useGameChannel", () => {
  it("does not subscribe when gameId is null", () => {
    renderHook(() => useGameChannel(null), { wrapper });
    expect(mockCreate).not.toHaveBeenCalled();
  });

  it("subscribes to GameChannel with the game id", () => {
    renderHook(() => useGameChannel("game-1"), { wrapper });
    expect(mockCreate).toHaveBeenCalledWith(
      { channel: "GameChannel", game_id: "game-1" },
      expect.any(Object)
    );
  });

  it("unsubscribes on unmount", () => {
    const { unmount } = renderHook(() => useGameChannel("game-1"), { wrapper });
    unmount();
    expect(mockUnsubscribe).toHaveBeenCalled();
  });

  it("preserves my_slot and my_next_card from cache on same-round broadcast", () => {
    queryClient.setQueryData(["game", "game-1"], makeGameState({
      my_slot: "player1",
      my_next_card: makeCard("K", "♠"),
    }));

    renderHook(() => useGameChannel("game-1"), { wrapper });
    act(() => simulateBroadcast(makeBroadcast()));

    const updated = queryClient.getQueryData<GameState>(["game", "game-1"]);
    expect(updated!.my_slot).toBe("player1");
    expect(updated!.my_next_card).toEqual(makeCard("K", "♠"));
  });

  it("updates my_next_card from broadcast on round change (player1)", () => {
    queryClient.setQueryData(["game", "game-1"], makeGameState({
      round: 1,
      my_slot: "player1",
      my_next_card: makeCard("K", "♠"),
    }));

    renderHook(() => useGameChannel("game-1"), { wrapper });

    act(() => simulateBroadcast(makeBroadcast({
      round: 2,
      player1_next_card: makeCard("7", "♣"),
      player2_next_card: makeCard("2", "♦"),
    })));

    const updated = queryClient.getQueryData<GameState>(["game", "game-1"]);
    expect(updated!.my_next_card).toEqual(makeCard("7", "♣"));
    expect(updated!.round).toBe(2);
  });

  it("uses player2_next_card when my_slot is player2 on round change", () => {
    queryClient.setQueryData(["game", "game-1"], makeGameState({
      round: 1,
      my_slot: "player2",
      my_next_card: makeCard("K", "♠"),
    }));

    renderHook(() => useGameChannel("game-1"), { wrapper });
    act(() => simulateBroadcast(makeBroadcast({
      round: 2,
      player1_next_card: makeCard("7", "♣"),
      player2_next_card: makeCard("2", "♦"),
    })));

    const updated = queryClient.getQueryData<GameState>(["game", "game-1"]);
    expect(updated!.my_next_card).toEqual(makeCard("2", "♦"));
  });

  it("merges broadcast fields into cache", () => {
    queryClient.setQueryData(["game", "game-1"], makeGameState());

    renderHook(() => useGameChannel("game-1"), { wrapper });

    act(() => simulateBroadcast(makeBroadcast({ player1_peg: 5, player2_peg: 3 })));

    const updated = queryClient.getQueryData<GameState>(["game", "game-1"]);
    expect(updated!.player1_peg).toBe(5);
    expect(updated!.player2_peg).toBe(3);
  });

  it("invalidates query when no cached data exists", () => {
    const spy = vi.spyOn(queryClient, "invalidateQueries");
    renderHook(() => useGameChannel("game-1"), { wrapper });
    act(() => simulateBroadcast(makeBroadcast()));
    expect(spy).toHaveBeenCalledWith({ queryKey: ["game", "game-1"] });
  });

  it("calls onOpponentCardPlayed when opponent places a card", () => {
    const boardWithNewCard = emptyBoard.map((r) => [...r]);
    boardWithNewCard[1][3] = makeCard("A", "♣");

    queryClient.setQueryData(["game", "game-1"], makeGameState({
      my_slot: "player1",
      current_turn: "player2",
    }));

    const onOpponentCardPlayed = vi.fn();
    renderHook(() => useGameChannel("game-1", onOpponentCardPlayed), { wrapper });
    act(() => simulateBroadcast(makeBroadcast({ board: boardWithNewCard })));

    expect(onOpponentCardPlayed).toHaveBeenCalledWith(1, 3);
  });

  it("does not call onOpponentCardPlayed when it was my turn", () => {
    const boardWithNewCard = emptyBoard.map((r) => [...r]);
    boardWithNewCard[1][3] = makeCard("A", "♣");

    queryClient.setQueryData(["game", "game-1"], makeGameState({
      my_slot: "player1",
      current_turn: "player1",
    }));

    const onOpponentCardPlayed = vi.fn();
    renderHook(() => useGameChannel("game-1", onOpponentCardPlayed), { wrapper });
    act(() => simulateBroadcast(makeBroadcast({ board: boardWithNewCard })));

    expect(onOpponentCardPlayed).not.toHaveBeenCalled();
  });
});
