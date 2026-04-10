# Card Deal Flip Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a card is placed and the server is resolving the next card, show a face-down card in the preview slot instead of an empty placeholder, then flip-reveal the new card when it arrives.

**Architecture:** Two isolated changes — a CSS keyframe for the flip animation, and updated render logic in `CardPreview` that uses `isLoading` + `card` to drive three states (face-down, flip-in, normal). A `useRef`/`useEffect` combo detects the `pending→card` transition to trigger the animation.

**Tech Stack:** React 19, TypeScript, Tailwind CSS v4, CSS keyframes

---

## File Map

| File | Change |
|---|---|
| `app/frontend/entrypoints/application.css` | Add `@keyframes card-flip-in` + `.card-flip-in` class |
| `app/frontend/components/CardPreview.tsx` | Add `wasLoadingRef`, `isFlipping` state, face-down card render branch |

> Note: No JavaScript test suite exists in this project. Verification is manual via `bin/dev`.

---

### Task 1: Add CSS flip keyframe

**Files:**
- Modify: `app/frontend/entrypoints/application.css`

- [ ] **Step 1: Add the keyframe and utility class**

Open `app/frontend/entrypoints/application.css`. After the existing `confetti-piece` block (currently ends around line 33), append:

```css
@keyframes card-flip-in {
  0%   { transform: rotateY(90deg); opacity: 0; }
  100% { transform: rotateY(0deg);  opacity: 1; }
}
.card-flip-in {
  animation: card-flip-in 0.25s ease-out forwards;
}
```

The full file should now look like:

```css
@import "tailwindcss";

@keyframes card-flash {
  0% {
    box-shadow: 0 0 0 3px rgba(251, 191, 36, 1), 0 0 24px rgba(251, 191, 36, 0.8), inset 0 0 16px rgba(251, 191, 36, 0.25);
  }
  100% {
    box-shadow: none;
  }
}

.card-just-played {
  animation: card-flash 4s ease-out forwards;
}

@keyframes confetti-fall {
  0% {
    transform: translateY(-24px) rotate(0deg);
    opacity: 1;
  }
  85% {
    opacity: 1;
  }
  100% {
    transform: translateY(105vh) rotate(800deg);
    opacity: 0;
  }
}

.confetti-piece {
  animation: confetti-fall linear infinite;
}

@keyframes card-flip-in {
  0%   { transform: rotateY(90deg); opacity: 0; }
  100% { transform: rotateY(0deg);  opacity: 1; }
}
.card-flip-in {
  animation: card-flip-in 0.25s ease-out forwards;
}
```

- [ ] **Step 2: Commit**

```bash
git add app/frontend/entrypoints/application.css
git commit -m "feat: add card-flip-in CSS animation"
```

---

### Task 2: Update CardPreview with face-down state and flip trigger

**Files:**
- Modify: `app/frontend/components/CardPreview.tsx`

- [ ] **Step 1: Replace the file contents**

Replace the entire file with:

```tsx
// app/frontend/components/CardPreview.tsx
import React, { useState, useRef, useEffect } from "react";
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

const cardShape = "w-14 h-20 rounded-lg border-2 flex flex-col items-center justify-center font-bold";

export function CardPreview({ card, deckSize, isMyTurn, onDiscard, canDiscard, isLoading }: CardPreviewProps) {
  const wasLoadingRef = useRef(false);
  const [isFlipping, setIsFlipping] = useState(false);

  useEffect(() => {
    if (wasLoadingRef.current && !isLoading && card) {
      setIsFlipping(true);
      const t = setTimeout(() => setIsFlipping(false), 250);
      return () => clearTimeout(t);
    }
    wasLoadingRef.current = isLoading;
  }, [isLoading, card]);

  let cardEl: React.ReactNode;

  if (isLoading && !card) {
    // Face-down card while server resolves the next card
    cardEl = (
      <div className={`${cardShape} border-slate-500 bg-slate-800`}>
        <span className="text-slate-600 text-2xl select-none">✦</span>
      </div>
    );
  } else if (card) {
    cardEl = (
      <div className={`${cardShape} ${isMyTurn ? "border-green-400 bg-slate-800 shadow-green-900 shadow-lg" : "border-slate-600 bg-slate-800"}${isFlipping ? " card-flip-in" : ""}`}>
        <span className="text-slate-100 text-2xl leading-none">{card.rank}</span>
        <span className={`${SUIT_COLOR[card.suit] ?? "text-slate-100"} text-2xl leading-none`}>{card.suit}</span>
      </div>
    );
  } else {
    // No card, not loading — opponent's turn or no card left
    cardEl = (
      <div className="w-14 h-20 rounded-lg border-2 border-dashed border-slate-700 bg-slate-900" />
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <span className="text-slate-500 text-xs uppercase tracking-wider">Your card</span>

      {cardEl}

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
```

- [ ] **Step 2: Start dev server and verify manually**

```bash
bin/dev
```

Open the game in a browser. Place a card on the board. Verify:
1. The card preview immediately shows a face-down slate card with a `✦` glyph (not an empty dashed box)
2. ~1s later, the card flips in (rotates from the side) to reveal the new card
3. Discard flow: click "Discard to crib" — same face-down card appears during the pending window, then the new card flips in
4. On error (disconnect wifi before clicking) — the face-down card does not appear (optimistic rollback restores the original card)

- [ ] **Step 3: Commit**

```bash
git add app/frontend/components/CardPreview.tsx
git commit -m "feat: show face-down card while next card loads, flip-reveal on arrival"
```
