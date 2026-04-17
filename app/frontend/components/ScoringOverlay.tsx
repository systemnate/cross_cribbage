// app/frontend/components/ScoringOverlay.tsx
import React, { useEffect, useState } from "react";
import type { GameState } from "../types/game";
import { MiniCard } from "./MiniCard";

interface ScoringOverlayProps {
  game: GameState;
  mySlot: "player1" | "player2";
  onConfirm: () => void;
  isConfirmPending: boolean;
}

export function ScoringOverlay({ game, mySlot, onConfirm, isConfirmPending }: ScoringOverlayProps) {
  const [countdown, setCountdown] = useState(30);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (game.status !== "scoring") {
      setVisible(false);
      return;
    }
    const timer = setTimeout(() => setVisible(true), 2000);
    return () => clearTimeout(timer);
  }, [game.status, game.round]);

  useEffect(() => {
    if (!visible) return;
    setCountdown(30);
    const interval = setInterval(() => {
      setCountdown((n) => Math.max(0, n - 1));
    }, 1000);
    return () => clearInterval(interval);
  }, [visible]);

  if (!visible) return null;

  const myScores  = mySlot === "player1" ? game.col_scores : game.row_scores;
  const oppScores = mySlot === "player1" ? game.row_scores : game.col_scores;
  const myTotal   = myScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner === mySlot ? (game.crib_score ?? 0) : 0);
  const oppTotal  = oppScores.reduce<number>((s, v) => s + (v ?? 0), 0) +
    (game.crib_owner !== null && game.crib_owner !== mySlot ? (game.crib_score ?? 0) : 0);

  const iConfirmed       = mySlot === "player1"
    ? game.player1_confirmed_scoring
    : game.player2_confirmed_scoring;
  const opponentConfirmed = mySlot === "player1"
    ? game.player2_confirmed_scoring
    : game.player1_confirmed_scoring;

  const myPeg  = mySlot === "player1" ? game.player1_peg : game.player2_peg;
  const oppPeg = mySlot === "player1" ? game.player2_peg : game.player1_peg;

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
            {game.crib_owner !== null && game.crib_owner !== mySlot && (
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

        {game.crib_hand && game.crib_hand.length > 0 && (
          <div className="mb-4">
            <p className="text-yellow-400 text-xs font-semibold mb-2 text-center">
              Crib hand {game.crib_owner === mySlot ? "(yours)" : "(opponent's)"}
            </p>
            <div className="flex justify-center gap-1.5">
              {game.starter_card && <MiniCard card={game.starter_card} />}
              {game.crib_hand.map((card) => (
                <MiniCard key={card.id} card={card} />
              ))}
            </div>
          </div>
        )}

        <div className="text-center">
          {myTotal > oppTotal && <p className="text-green-400 font-bold mb-2">You won the round by {myTotal - oppTotal} pts</p>}
          {oppTotal > myTotal && <p className="text-red-400 font-bold mb-2">Opponent won the round by {oppTotal - myTotal} pts</p>}
          {myTotal === oppTotal && <p className="text-slate-400 mb-2">Round tied</p>}

          <div className="mb-3 rounded-lg border-2 border-slate-700 bg-black shadow-inner">
            <div className="px-3 py-1 border-b border-slate-800 text-[10px] font-bold tracking-[0.2em] text-amber-500/80 text-center">
              GAME SCORE
            </div>
            <div className="grid grid-cols-2 divide-x divide-slate-800">
              <div className="px-3 py-2 flex flex-col items-center">
                <span className="text-[10px] font-bold tracking-widest text-slate-400">YOU</span>
                <span className="font-mono text-3xl font-black text-amber-400 tabular-nums [text-shadow:0_0_8px_rgba(251,191,36,0.6)]">
                  {String(myPeg).padStart(2, "0")}
                </span>
              </div>
              <div className="px-3 py-2 flex flex-col items-center">
                <span className="text-[10px] font-bold tracking-widest text-slate-400">OPP</span>
                <span className="font-mono text-3xl font-black text-amber-400 tabular-nums [text-shadow:0_0_8px_rgba(251,191,36,0.6)]">
                  {String(oppPeg).padStart(2, "0")}
                </span>
              </div>
            </div>
            <div className="px-3 py-0.5 border-t border-slate-800 text-[9px] tracking-widest text-slate-500 text-center">
              FIRST TO 31
            </div>
          </div>

          <button
            onClick={onConfirm}
            disabled={iConfirmed || isConfirmPending}
            className="w-full mt-2 mb-3 px-4 py-2 rounded-lg font-semibold text-sm bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white transition-colors"
          >
            {iConfirmed ? "Ready" : isConfirmPending ? "Confirming…" : "Ready for next round"}
          </button>

          <div className="flex justify-between text-xs mb-2">
            <span className={iConfirmed ? "text-green-400" : "text-slate-500"}>
              You: {iConfirmed ? "Ready ✓" : "waiting…"}
            </span>
            <span className={opponentConfirmed ? "text-green-400" : "text-slate-500"}>
              Opponent: {opponentConfirmed ? "Ready ✓" : "waiting…"}
            </span>
          </div>

          <p className="text-slate-500 text-sm">Next round in {countdown}…</p>
        </div>
      </div>
    </div>
  );
}
