// app/frontend/components/PegBoard.tsx
import React from "react";

interface PegBoardProps {
  myPeg: number;
  opponentPeg: number;
  mySlot: "player1" | "player2";
  winner: "player1" | "player2" | null;
}

export function PegBoard({ myPeg, opponentPeg, mySlot, winner }: PegBoardProps) {
  const TOTAL = 31;

  return (
    <div className="flex items-center gap-3 bg-slate-900 rounded-lg px-4 py-2 border border-slate-700">
      <span className="text-slate-400 text-xs font-semibold uppercase tracking-wider whitespace-nowrap">
        Peg track
      </span>

      {/* Track */}
      <div className="relative flex-1 h-4 bg-slate-800 rounded-full border border-slate-700 overflow-visible">
        {/* Tick marks at 5, 10, 15, 20, 25, 30 */}
        {[5, 10, 15, 20, 25, 30].map((n) => (
          <div
            key={n}
            className="absolute top-0 bottom-0 w-px bg-slate-600"
            style={{ left: `${(n / TOTAL) * 100}%` }}
          />
        ))}

        {/* Opponent peg (black) */}
        <div
          className="absolute top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-slate-400 border-2 border-slate-300 shadow transition-all duration-500"
          style={{ left: `calc(${(opponentPeg / TOTAL) * 100}% - 8px)` }}
          title={`Opponent: ${opponentPeg}`}
        />

        {/* My peg (red) */}
        <div
          className="absolute top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-red-500 border-2 border-red-300 shadow transition-all duration-500"
          style={{ left: `calc(${(myPeg / TOTAL) * 100}% - 8px)` }}
          title={`You: ${myPeg}`}
        />
      </div>

      <div className="text-xs font-mono whitespace-nowrap">
        <span className="text-red-400">{myPeg}</span>
        <span className="text-slate-500 mx-1">/</span>
        <span className="text-slate-400">{opponentPeg}</span>
        <span className="text-slate-600 ml-1">· {TOTAL}</span>
      </div>

      {winner && (
        <span className="text-yellow-400 text-xs font-bold">
          {winner === mySlot ? "You win!" : "Opponent wins!"}
        </span>
      )}
    </div>
  );
}
