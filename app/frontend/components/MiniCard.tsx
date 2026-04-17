import React from "react";
import type { Card } from "../types/game";

export const SUIT_COLOR: Record<string, string> = {
  "♥": "text-red-400", "♦": "text-red-400",
  "♠": "text-slate-100", "♣": "text-slate-100",
};

export function MiniCard({ card }: { card: Card }) {
  return (
    <div className="w-9 h-12 rounded border border-slate-600 bg-slate-800 flex flex-col items-center justify-center gap-0.5 shadow-sm">
      <span className="text-slate-100 text-xs font-bold leading-none">{card.rank}</span>
      <span className={`${SUIT_COLOR[card.suit] ?? "text-slate-100"} text-xs leading-none`}>{card.suit}</span>
    </div>
  );
}
