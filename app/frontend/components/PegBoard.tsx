// app/frontend/components/PegBoard.tsx
import React from "react";

interface PegBoardProps {
  myPeg: number;
  opponentPeg: number;
  myBoardScore: number;
  oppBoardScore: number;
  mySlot: "player1" | "player2";
  winner: "player1" | "player2" | null;
}

export function PegBoard({ myPeg, opponentPeg, myBoardScore, oppBoardScore, mySlot, winner }: PegBoardProps) {
  const TOTAL = 31;

  // player1 is always red, player2 is always slate — consistent across both clients
  const myColor    = mySlot === "player1" ? "bg-red-500 border-red-300"     : "bg-slate-400 border-slate-300";
  const oppColor   = mySlot === "player1" ? "bg-slate-400 border-slate-300" : "bg-red-500 border-red-300";
  const myText     = mySlot === "player1" ? "text-red-400"   : "text-slate-300";
  const oppText    = mySlot === "player1" ? "text-slate-300" : "text-red-400";

  return (
    <div className="flex items-center gap-3 bg-slate-900 rounded-lg px-2 py-2 sm:px-4 border border-slate-700">
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

        {/* Opponent peg */}
        <div
          className={`absolute top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border-2 shadow transition-all duration-500 ${oppColor}`}
          style={{ left: `calc(${(opponentPeg / TOTAL) * 100}% - 8px)` }}
          title={`Opponent: ${opponentPeg}`}
        />

        {/* My peg */}
        <div
          className={`absolute top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border-2 shadow transition-all duration-500 ${myColor}`}
          style={{ left: `calc(${(myPeg / TOTAL) * 100}% - 8px)` }}
          title={`You: ${myPeg}`}
        />
      </div>

      <div className="text-xs font-mono whitespace-nowrap flex flex-col items-end gap-0.5">
        <span>
          <span className="text-slate-500">You </span>
          <span className={`font-bold ${myText}`}>{myPeg}</span>
          <span className="text-slate-600 ml-1">(+{myBoardScore})</span>
        </span>
        <span>
          <span className="text-slate-500">Opp </span>
          <span className={`font-bold ${oppText}`}>{opponentPeg}</span>
          <span className="text-slate-600 ml-1">(+{oppBoardScore})</span>
        </span>
      </div>

      {winner && (
        <span className="text-yellow-400 text-xs font-bold">
          {winner === mySlot ? "You win!" : "Opponent wins!"}
        </span>
      )}
    </div>
  );
}
