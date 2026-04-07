import React from "react";
import { BoardCell } from "./BoardCell";
import type { Card } from "../types/game";

interface BoardProps {
  board: (Card | null)[][];
  mySlot: "player1" | "player2";
  starter: Card | null;
  rowScores: (number | null)[];
  colScores: (number | null)[];
  isMyTurn: boolean;
  onCellClick: (row: number, col: number) => void;
}

function transpose<T>(matrix: T[][]): T[][] {
  if (!matrix[0]) return matrix;
  return matrix[0].map((_, c) => matrix.map((row) => row[c]));
}

export function Board({
  board, mySlot, starter, rowScores, colScores, isMyTurn, onCellClick
}: BoardProps) {
  // Player 2 sees the board transposed (their scoring hands become columns)
  const displayBoard = mySlot === "player2" ? transpose(board) : board;

  // Player 1 scores columns (col_scores); Player 2 scores rows from server = col_scores from display POV
  const myHandScores  = mySlot === "player1" ? colScores : rowScores;
  const oppHandScores = mySlot === "player1" ? rowScores : colScores;

  function handleClick(displayRow: number, displayCol: number) {
    if (!isMyTurn) return;
    // Map display coords back to server coords
    const [serverRow, serverCol] =
      mySlot === "player2" ? [displayCol, displayRow] : [displayRow, displayCol];
    onCellClick(serverRow, serverCol);
  }

  return (
    <div className="flex flex-col gap-1">
      {displayBoard.map((row, rIdx) => (
        <div key={rIdx} className="flex items-center gap-1">
          {row.map((cell, cIdx) => (
            <BoardCell
              key={cIdx}
              card={cell}
              isStarter={!!(cell && starter && cell.id === starter.id)}
              isClickable={isMyTurn && !cell}
              onClick={() => handleClick(rIdx, cIdx)}
            />
          ))}
          {/* Opponent's row score (right of each row) */}
          <span className="w-8 text-right text-xs font-mono text-blue-400 ml-1">
            {oppHandScores[rIdx] != null ? oppHandScores[rIdx] : "—"}
          </span>
        </div>
      ))}

      {/* My column scores (below each column) */}
      <div className="flex gap-1 mt-1">
        {displayBoard[0]?.map((_, cIdx) => (
          <div key={cIdx} className="w-11 text-center text-xs font-mono text-green-400">
            {myHandScores[cIdx] != null ? myHandScores[cIdx] : "—"}
          </div>
        ))}
        <div className="w-8" /> {/* spacer for row score column */}
      </div>
    </div>
  );
}
