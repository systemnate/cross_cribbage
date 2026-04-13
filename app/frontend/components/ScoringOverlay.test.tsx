import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import "@testing-library/jest-dom";
import React from "react";
import { ScoringOverlay } from "./ScoringOverlay";
import type { GameState } from "../types/game";

function makeGameState(overrides: Partial<GameState> = {}): GameState {
  return {
    id: "game-1",
    status: "scoring",
    current_turn: null,
    round: 1,
    crib_owner: "player1",
    board: Array.from({ length: 5 }, () => Array(5).fill(null)),
    starter_card: { rank: "5", suit: "♥", id: "5♥" },
    row_scores: [2, 4, 6, 0, 3],
    col_scores: [1, 8, 0, 5, 2],
    crib_score: 4,
    crib_size: { player1: 2, player2: 2 },
    deck_size: { player1: 0, player2: 0 },
    player1_peg: 10,
    player2_peg: 7,
    winner_slot: null,
    player1_confirmed_scoring: false,
    player2_confirmed_scoring: false,
    crib_hand: [
      { rank: "3", suit: "♥", id: "3♥" },
      { rank: "7", suit: "♠", id: "7♠" },
    ],
    vs_computer: false,
    my_slot: "player1",
    my_next_card: null,
    ...overrides,
  };
}

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

/** Advance past the 2-second visibility delay so the overlay renders */
function makeVisible() {
  act(() => { vi.advanceTimersByTime(2100); });
}

describe("ScoringOverlay", () => {
  it("renders null when status is not scoring", () => {
    const game = makeGameState({ status: "active" });
    const { container } = render(
      <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
    );
    makeVisible();
    expect(container.firstChild).toBeNull();
  });

  it("is hidden initially and appears after delay", () => {
    const game = makeGameState();
    const { container } = render(
      <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
    );
    // Before the 2s delay, overlay is not visible
    expect(container.firstChild).toBeNull();

    makeVisible();
    expect(screen.getByText(/Round \d+ Scores/)).toBeInTheDocument();
  });

  it("shows round number", () => {
    const game = makeGameState({ round: 3 });
    render(
      <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
    );
    makeVisible();
    expect(screen.getByText("Round 3 Scores")).toBeInTheDocument();
  });

  describe("score calculations for player1", () => {
    it("computes my total as col_scores + crib (when I own crib)", () => {
      // col_scores: [1, 8, 0, 5, 2] = 16, crib_score: 4 → total: 20
      const game = makeGameState({ crib_owner: "player1" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("20")).toBeInTheDocument();
    });

    it("computes opponent total as row_scores + crib (when opponent owns crib)", () => {
      // row_scores: [2, 4, 6, 0, 3] = 15, crib_score: 4 → opponent total: 19
      const game = makeGameState({ crib_owner: "player2" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("16")).toBeInTheDocument();
      expect(screen.getByText("19")).toBeInTheDocument();
    });
  });

  describe("score calculations for player2", () => {
    it("computes my total as row_scores + crib (when I own crib)", () => {
      // row_scores: [2, 4, 6, 0, 3] = 15, crib_score: 4 → total: 19
      const game = makeGameState({ crib_owner: "player2" });
      render(
        <ScoringOverlay game={game} mySlot="player2" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("19")).toBeInTheDocument();
    });
  });

  describe("round result messages", () => {
    it("shows winning message when my total > opponent total", () => {
      const game = makeGameState({ crib_owner: "player1" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("You won the round by 5 pts")).toBeInTheDocument();
    });

    it("shows losing message when opponent total > my total", () => {
      const game = makeGameState({ crib_owner: "player2" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Opponent won the round by 3 pts")).toBeInTheDocument();
    });

    it("shows tied message when totals are equal", () => {
      const game = makeGameState({
        col_scores: [3, 3, 3, 3, 3],
        row_scores: [3, 3, 3, 3, 3],
        crib_score: 0,
        crib_owner: "player1",
      });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Round tied")).toBeInTheDocument();
    });
  });

  describe("confirmation state", () => {
    it("shows 'Ready for next round' button when not confirmed", () => {
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Ready for next round")).toBeInTheDocument();
    });

    it("shows 'Ready' when I have confirmed", () => {
      const game = makeGameState({ player1_confirmed_scoring: true });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByRole("button", { name: "Ready" })).toBeDisabled();
    });

    it("calls onConfirm when button is clicked", () => {
      const onConfirm = vi.fn();
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={onConfirm} isConfirmPending={false} />
      );
      makeVisible();
      fireEvent.click(screen.getByText("Ready for next round"));
      expect(onConfirm).toHaveBeenCalledOnce();
    });

    it("disables button when confirmation is pending", () => {
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={true} />
      );
      makeVisible();
      expect(screen.getByText("Confirming…")).toBeDisabled();
    });
  });

  describe("countdown timer", () => {
    it("starts at 30 after becoming visible and decrements", () => {
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Next round in 30…")).toBeInTheDocument();

      act(() => { vi.advanceTimersByTime(3000); });
      expect(screen.getByText("Next round in 27…")).toBeInTheDocument();
    });

    it("does not go below 0", () => {
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      act(() => { vi.advanceTimersByTime(35000); });
      expect(screen.getByText("Next round in 0…")).toBeInTheDocument();
    });
  });

  describe("crib hand display", () => {
    it("renders crib hand cards with starter card", () => {
      const game = makeGameState();
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getAllByText("5").length).toBeGreaterThan(0);
      expect(screen.getAllByText("3").length).toBeGreaterThan(0);
      expect(screen.getAllByText("7").length).toBeGreaterThan(0);
    });

    it("labels crib as yours when you own it", () => {
      const game = makeGameState({ crib_owner: "player1" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Crib hand (yours)")).toBeInTheDocument();
    });

    it("labels crib as opponent's when they own it", () => {
      const game = makeGameState({ crib_owner: "player2" });
      render(
        <ScoringOverlay game={game} mySlot="player1" onConfirm={vi.fn()} isConfirmPending={false} />
      );
      makeVisible();
      expect(screen.getByText("Crib hand (opponent's)")).toBeInTheDocument();
    });
  });
});
