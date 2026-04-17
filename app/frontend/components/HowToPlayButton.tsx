import React, { useState, useEffect, useRef } from "react";
import { MiniCard } from "./MiniCard";
import type { Card } from "../types/game";

const card = (rank: string, suit: string, id: string): Card => ({ rank, suit, id });

export function HowToPlayButton() {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const handleClose = () => {
    setOpen(false);
    triggerRef.current?.focus();
  };

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen(true)}
        aria-label="How to play"
        className="fixed bottom-3 right-3 z-40 w-10 h-10 rounded-full bg-slate-800 hover:bg-slate-700 border-2 border-slate-600 text-slate-200 text-lg font-bold shadow-lg transition-colors flex items-center justify-center"
      >
        ?
      </button>
      {open && <HowToPlayModal onClose={handleClose} />}
    </>
  );
}

function HowToPlayModal({ onClose }: { onClose: () => void }) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label="How to play Cross Cribbage"
        onClick={(e) => e.stopPropagation()}
        className="bg-slate-900 border border-slate-700 rounded-xl p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto relative"
      >
        <button
          ref={closeRef}
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-3 right-3 w-8 h-8 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-100 text-2xl leading-none flex items-center justify-center"
        >
          ×
        </button>

        <h2 className="text-yellow-400 font-black text-xl mb-4">How to play Cross Cribbage</h2>

        <div className="space-y-5 text-sm text-slate-300">
          {/* 2. Goal */}
          <section>
            <h3 className="text-slate-200 font-bold mb-1">Goal</h3>
            <p>First to 31 pegging points wins the game.</p>
          </section>

          {/* 3. Your direction */}
          <section>
            <h3 className="text-slate-200 font-bold mb-1">Your direction</h3>
            <p>
              Your hands run <span className="text-green-400 font-semibold">down ↓</span>. Your opponent's hands run{" "}
              <span className="text-blue-400 font-semibold">across →</span>. When the board fills, every column you see is one of your 5-card hands.
            </p>
          </section>

          {/* 4. Each round */}
          <section>
            <h3 className="text-slate-200 font-bold mb-1">Each round</h3>
            <ul className="list-disc pl-5 space-y-1">
              <li>14 cards are dealt to each player.</li>
              <li>The center cell is the starter card, shared by both players.</li>
              <li>
                <strong>Discard 2 cards to the crib</strong> before you've placed enough cards to fill the board — use the purple{" "}
                <em>Discard to crib</em> button on your card preview.
              </li>
              <li>You and your opponent take turns placing one card at a time until all 24 empty cells are filled.</li>
            </ul>
          </section>

          {/* 5. Scoring rules */}
          <section>
            <h3 className="text-slate-200 font-bold mb-1">Scoring</h3>
            <p className="mb-2">
              Each row and column is a 5-card hand. The center cell holds the starter, so the <strong>middle row and middle column</strong> include it; the other rows and columns do not.
            </p>
            <p className="mb-3">
              <span className="text-green-400 font-semibold">Player 1 scores all 5 columns.</span>{" "}
              <span className="text-blue-400 font-semibold">Player 2 scores all 5 rows.</span>{" "}
              The crib is a separate 4-card hand plus the starter, scored only for its owner.
            </p>
            <ul className="space-y-3">
              <li>
                <div className="font-semibold text-slate-200">Fifteens — 2 pts each</div>
                <div className="text-slate-400 text-xs mb-1">Any combination of cards in the hand that sums to 15 (face cards = 10, Ace = 1).</div>
                <div className="flex gap-1 items-center">
                  <MiniCard card={card("5", "♥", "ex-15-a")} />
                  <span className="text-slate-500">+</span>
                  <MiniCard card={card("10", "♣", "ex-15-b")} />
                  <span className="text-slate-500 text-xs ml-2">= 15 → 2 pts</span>
                </div>
              </li>

              <li>
                <div className="font-semibold text-slate-200">Pair — 2 pts · Three of a kind — 6 · Four of a kind — 12</div>
                <div className="text-slate-400 text-xs mb-1">Two or more cards of the same rank.</div>
                <div className="flex gap-1 items-center">
                  <MiniCard card={card("7", "♥", "ex-pair-a")} />
                  <span className="text-slate-500">+</span>
                  <MiniCard card={card("7", "♠", "ex-pair-b")} />
                  <span className="text-slate-500 text-xs ml-2">= pair → 2 pts</span>
                </div>
              </li>

              <li>
                <div className="font-semibold text-slate-200">Run — 1 pt per card (minimum 3)</div>
                <div className="text-slate-400 text-xs mb-1">Consecutive ranks, any suits.</div>
                <div className="flex gap-1 items-center">
                  <MiniCard card={card("4", "♦", "ex-run-a")} />
                  <span className="text-slate-500">+</span>
                  <MiniCard card={card("5", "♣", "ex-run-b")} />
                  <span className="text-slate-500">+</span>
                  <MiniCard card={card("6", "♥", "ex-run-c")} />
                  <span className="text-slate-500 text-xs ml-2">= run of 3 → 3 pts</span>
                </div>
              </li>

              <li>
                <div className="font-semibold text-slate-200">Flush — 5 pts</div>
                <div className="text-slate-400 text-xs mb-1">All 5 cards in the hand share a suit. (In the crib, all 4 crib cards and the starter must match.)</div>
              </li>

              <li>
                <div className="font-semibold text-slate-200">Nobs — 1 pt</div>
                <div className="text-slate-400 text-xs">
                  Scored only in the middle row and middle column (the two hands that contain the starter). If one of the other 4 cards in that hand is the Jack matching the starter's suit, it's worth 1 pt.
                </div>
              </li>

              <li>
                <div className="font-semibold text-slate-200">Nibs — 2 pts</div>
                <div className="text-slate-400 text-xs">If the starter card itself is a Jack, the crib owner scores 2 pts immediately.</div>
              </li>
            </ul>
          </section>

          {/* 7. Round end (section 6 — sample board — is added in Task 4) */}
          <section>
            <h3 className="text-slate-200 font-bold mb-1">End of round</h3>
            <p>The player who scores more that round pegs the point difference. First to 31 total pegging points wins the game.</p>
          </section>
        </div>
      </div>
    </div>
  );
}
