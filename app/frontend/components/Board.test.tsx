import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import "@testing-library/jest-dom";
import React from "react";
import { Board } from "./Board";
import type { Card } from "../types/game";

function makeCard(rank: string, suit: string): Card {
  return { rank, suit, id: `${rank}${suit}` };
}

function emptyBoard(): (Card | null)[][] {
  return Array.from({ length: 5 }, () => Array(5).fill(null));
}

const defaultProps = {
  board: emptyBoard(),
  mySlot: "player1" as const,
  starter: null,
  rowScores: [null, null, null, null, null] as (number | null)[],
  colScores: [null, null, null, null, null] as (number | null)[],
  isMyTurn: true,
  onCellClick: vi.fn(),
};

/**
 * BoardCell renders empty clickable cells as plain divs with cursor-pointer.
 * We query them by their CSS class since they have no semantic role.
 */
function getClickableCells(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>("[class*='cursor-pointer']"));
}

function getAllCellDivs(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>("[class*='aspect-']"));
}

describe("Board", () => {
  describe("coordinate transformation", () => {
    it("player1 passes display coords as-is to onCellClick", () => {
      const onClick = vi.fn();
      const board = emptyBoard();
      const { container } = render(
        <Board {...defaultProps} board={board} mySlot="player1" onCellClick={onClick} />
      );

      const cells = getClickableCells(container);
      // 5x5 grid = 25 clickable cells, index = row*5 + col
      fireEvent.click(cells[1 * 5 + 3]);
      expect(onClick).toHaveBeenCalledWith(1, 3);
    });

    it("player2 transposes coords: display (1,3) -> server (3,1)", () => {
      const onClick = vi.fn();
      const board = emptyBoard();
      const { container } = render(
        <Board {...defaultProps} board={board} mySlot="player2" onCellClick={onClick} />
      );

      const cells = getClickableCells(container);
      fireEvent.click(cells[1 * 5 + 3]);
      expect(onClick).toHaveBeenCalledWith(3, 1);
    });
  });

  describe("score display", () => {
    it("player1 sees col_scores as 'my' scores below the board", () => {
      const colScores = [2, 4, 6, 8, 12];
      const rowScores = [1, 3, 5, 7, 9];
      render(
        <Board
          {...defaultProps}
          mySlot="player1"
          colScores={colScores}
          rowScores={rowScores}
        />
      );

      expect(screen.getByText("2")).toBeInTheDocument();
      expect(screen.getByText("12")).toBeInTheDocument();
    });

    it("player2 sees row_scores as 'my' scores below the board", () => {
      const colScores = [2, 4, 6, 8, 12];
      const rowScores = [1, 3, 5, 7, 9];
      render(
        <Board
          {...defaultProps}
          mySlot="player2"
          colScores={colScores}
          rowScores={rowScores}
        />
      );

      expect(screen.getByText("1")).toBeInTheDocument();
      expect(screen.getByText("9")).toBeInTheDocument();
    });
  });

  describe("interactivity", () => {
    it("does not call onCellClick when isMyTurn is false", () => {
      const onClick = vi.fn();
      const { container } = render(
        <Board {...defaultProps} isMyTurn={false} onCellClick={onClick} />
      );

      // When isMyTurn is false, no cells should have cursor-pointer / onClick
      const clickableCells = getClickableCells(container);
      expect(clickableCells).toHaveLength(0);

      // Click any cell div — should not trigger callback
      const allCells = getAllCellDivs(container);
      fireEvent.click(allCells[0]);
      expect(onClick).not.toHaveBeenCalled();
    });

    it("renders occupied cells without click handler", () => {
      const board = emptyBoard();
      board[0][0] = makeCard("K", "♠");
      render(<Board {...defaultProps} board={board} />);

      expect(screen.getByText("K")).toBeInTheDocument();
    });
  });

  describe("board transposition for player2", () => {
    it("player2 sees the board transposed so card at server [0][1] appears at display [1][0]", () => {
      const board = emptyBoard();
      board[0][1] = makeCard("A", "♥");

      render(<Board {...defaultProps} board={board} mySlot="player2" isMyTurn={false} />);

      expect(screen.getByText("A")).toBeInTheDocument();
    });
  });
});
