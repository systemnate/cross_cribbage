// app/frontend/components/CardPreview.tsx
import React from "react";
import type { Card } from "../types/game";

interface CardPreviewProps {
  card: Card | null;
  deckSize: number;
  isMyTurn: boolean;
  onDiscard: () => void;
  canDiscard: boolean;  // false if already used 2 discards
  isLoading: boolean;
}

const SUIT_COLOR: Record<string, string> = {
  "♥": "text-red-400", "♦": "text-red-400",
  "♠": "text-slate-100", "♣": "text-slate-100",
};

export function CardPreview({ card, deckSize, isMyTurn, onDiscard, canDiscard, isLoading }: CardPreviewProps) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-slate-500 text-xs uppercase tracking-wider">Your card</span>

      {card ? (
        <div className={`w-14 h-20 rounded-lg border-2 flex flex-col items-center justify-center font-bold
          ${isMyTurn ? "border-green-400 bg-slate-800 shadow-green-900 shadow-lg" : "border-slate-600 bg-slate-800"}`}>
          <span className="text-slate-100 text-2xl leading-none">{card.rank}</span>
          <span className={`${SUIT_COLOR[card.suit] ?? "text-slate-100"} text-2xl leading-none`}>{card.suit}</span>
        </div>
      ) : (
        <div className="w-14 h-20 rounded-lg border-2 border-dashed border-slate-700 bg-slate-900" />
      )}

      <span className="text-slate-600 text-xs">{deckSize} left</span>

      {isMyTurn && canDiscard && card && (
        <button
          onClick={onDiscard}
          disabled={isLoading}
          className="rounded bg-purple-700 hover:bg-purple-600 disabled:opacity-50 text-white text-xs font-semibold py-1.5 px-2 transition-colors"
        >
          {isLoading ? "…" : "Discard to crib"}
        </button>
      )}

      {!isMyTurn && (
        <span className="text-slate-600 text-xs italic">Waiting…</span>
      )}
    </div>
  );
}
