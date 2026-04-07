// app/frontend/components/ScoringOverlay.tsx
import React, { useEffect, useState } from "react";
import type { GameState } from "../types/game";

interface ScoringOverlayProps {
  game: GameState;
  mySlot: "player1" | "player2";
}

export function ScoringOverlay({ game, mySlot }: ScoringOverlayProps) {
  const [countdown, setCountdown] = useState(3);

  useEffect(() => {
    if (game.status !== "scoring") return;
    setCountdown(3);
    const interval = setInterval(() => {
      setCountdown((n) => Math.max(0, n - 1));
    }, 1000);
    return () => clearInterval(interval);
  }, [game.status, game.round]);

  const myScores  = mySlot === "player1" ? game.col_scores : game.row_scores;
  const oppScores = mySlot === "player1" ? game.row_scores : game.col_scores;
  const myTotal   = myScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner === mySlot ? (game.crib_score ?? 0) : 0);
  const oppTotal  = oppScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner !== mySlot ? (game.crib_score ?? 0) : 0);

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-slate-900 border border-slate-700 rounded-xl p-6 max-w-sm w-full">
        <h2 className="text-yellow-400 font-black text-xl text-center mb-4">Round {game.round} Scores</h2>

        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-green-400 text-xs font-semibold mb-1">Your hands</p>
            {myScores.map((s, i) => (
              <div key={i} className="flex justify-between text-sm font-mono">
                <span className="text-slate-400">Hand {i + 1}</span>
                <span className="text-green-300">{s ?? 0}</span>
              </div>
            ))}
            {game.crib_owner === mySlot && (
              <div className="flex justify-between text-sm font-mono border-t border-slate-700 mt-1 pt-1">
                <span className="text-yellow-400">Crib</span>
                <span className="text-yellow-300">{game.crib_score ?? 0}</span>
              </div>
            )}
            <div className="flex justify-between text-sm font-mono font-bold border-t border-slate-600 mt-1 pt-1">
              <span className="text-slate-300">Total</span>
              <span className="text-green-400">{myTotal}</span>
            </div>
          </div>

          <div>
            <p className="text-blue-400 text-xs font-semibold mb-1">Opponent's hands</p>
            {oppScores.map((s, i) => (
              <div key={i} className="flex justify-between text-sm font-mono">
                <span className="text-slate-400">Hand {i + 1}</span>
                <span className="text-blue-300">{s ?? 0}</span>
              </div>
            ))}
            {game.crib_owner !== mySlot && (
              <div className="flex justify-between text-sm font-mono border-t border-slate-700 mt-1 pt-1">
                <span className="text-yellow-400">Crib</span>
                <span className="text-yellow-300">{game.crib_score ?? 0}</span>
              </div>
            )}
            <div className="flex justify-between text-sm font-mono font-bold border-t border-slate-600 mt-1 pt-1">
              <span className="text-slate-300">Total</span>
              <span className="text-blue-400">{oppTotal}</span>
            </div>
          </div>
        </div>

        <div className="text-center">
          {myTotal > oppTotal && <p className="text-green-400 font-bold mb-2">You lead by {myTotal - oppTotal} pts</p>}
          {oppTotal > myTotal && <p className="text-red-400 font-bold mb-2">Opponent leads by {oppTotal - myTotal} pts</p>}
          {myTotal === oppTotal && <p className="text-slate-400 mb-2">Tied this round</p>}
          <p className="text-slate-500 text-sm">Next round in {countdown}…</p>
        </div>
      </div>
    </div>
  );
}
