// app/frontend/components/CribArea.tsx
import React from "react";

interface CribAreaProps {
  myCribCount: number;      // how many I've discarded to crib this round
  opponentCribCount: number;
  isMyCrib: boolean;
  cribScore: number | null; // only set during scoring phase
}

export function CribArea({ myCribCount, opponentCribCount, isMyCrib, cribScore }: CribAreaProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-slate-500 text-xs uppercase tracking-wider">
        Crib {isMyCrib ? <span className="text-yellow-400">(yours)</span> : <span className="text-slate-500">(opponent's)</span>}
      </span>

      <div className="flex gap-1">
        {/* My 2 slots */}
        {[0, 1].map((i) => (
          <div key={`my-${i}`}
            className={`w-8 h-11 rounded border flex items-center justify-center text-xs
              ${i < myCribCount ? "border-slate-500 bg-slate-700 text-slate-300" : "border-dashed border-slate-700 bg-slate-900"}`}>
            {i < myCribCount ? "✓" : ""}
          </div>
        ))}
        <div className="w-px bg-slate-700 mx-0.5" />
        {/* Opponent's 2 slots */}
        {[0, 1].map((i) => (
          <div key={`opp-${i}`}
            className={`w-8 h-11 rounded border flex items-center justify-center text-xs
              ${i < opponentCribCount ? "border-slate-500 bg-slate-700 text-slate-400" : "border-dashed border-slate-700 bg-slate-900"}`}>
            {i < opponentCribCount ? "?" : ""}
          </div>
        ))}
      </div>

      {cribScore != null && (
        <span className={`text-xs font-mono font-bold ${isMyCrib ? "text-green-400" : "text-blue-400"}`}>
          Score: {cribScore}
        </span>
      )}
    </div>
  );
}
