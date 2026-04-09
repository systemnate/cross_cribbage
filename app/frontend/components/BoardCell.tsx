import React from "react";
import type { Card } from "../types/game";

interface BoardCellProps {
  card: Card | null;
  isStarter: boolean;
  isClickable: boolean;
  onClick: () => void;
}

const SUIT_COLOR: Record<string, string> = {
  "♥": "text-red-400",
  "♦": "text-red-400",
  "♠": "text-slate-200",
  "♣": "text-slate-200",
};

export function BoardCell({ card, isStarter, isClickable, onClick }: BoardCellProps) {
  const base = "h-full md:h-auto md:flex-1 md:min-w-0 aspect-[11/14] rounded-md flex flex-col items-center justify-center text-xl font-bold select-none transition-all";

  if (!card) {
    const empty = isClickable
      ? `${base} border-2 border-dashed border-green-500 bg-slate-900 cursor-pointer hover:bg-green-950 hover:border-green-400`
      : `${base} border border-slate-700 bg-slate-900`;
    return <div className={empty} onClick={isClickable ? onClick : undefined} />;
  }

  const borderClass = isStarter ? "border-2 border-yellow-400" : "border border-slate-600";
  const bgClass     = isStarter ? "bg-slate-800" : "bg-slate-800";
  const suitColor   = SUIT_COLOR[card.suit] ?? "text-slate-200";

  return (
    <div className={`${base} ${borderClass} ${bgClass}`}>
      <span className="text-slate-100 leading-none">{card.rank}</span>
      <span className={`${suitColor} text-2xl leading-none`}>{card.suit}</span>
    </div>
  );
}
