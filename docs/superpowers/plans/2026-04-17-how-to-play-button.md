# How-To-Play Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating "?" button in the bottom-right of `GamePage` that opens a modal explaining how to play Cross Cribbage, including scoring rules with mini-card examples and one annotated sample 5×5 board.

**Architecture:** Pure frontend change. A new `HowToPlayButton` component owns a `fixed`-positioned trigger and an open/closed modal (same visual pattern as `ScoringOverlay`). The shared `MiniCard` visual is extracted from `ScoringOverlay` to its own file so it can be reused by the help modal.

**Tech Stack:** React 19, TypeScript, Tailwind CSS v4. No new dependencies. No backend or API changes. The project has no JS test suite (per `CLAUDE.md`), so verification is manual in a browser — each task ends with explicit manual checks.

**Spec:** `docs/superpowers/specs/2026-04-17-how-to-play-button-design.md`

---

## File map

| File | Action | Responsibility |
| --- | --- | --- |
| `app/frontend/components/MiniCard.tsx` | **Create** | Tiny card visual (rank + suit), shared across modals |
| `app/frontend/components/ScoringOverlay.tsx` | Modify | Import `MiniCard` instead of defining it locally |
| `app/frontend/components/HowToPlayButton.tsx` | **Create** | Floating trigger button + modal with all rules content + sample board |
| `app/frontend/components/GamePage.tsx` | Modify | Render `<HowToPlayButton />` once, visible in every game state |

---

## Task 1: Extract `MiniCard` to its own file

Small refactor so both `ScoringOverlay` and the new help modal can use the identical visual. Done first to keep the later tasks focused on new UI.

**Files:**
- Create: `app/frontend/components/MiniCard.tsx`
- Modify: `app/frontend/components/ScoringOverlay.tsx` (remove local `MiniCard` and `SUIT_COLOR`, import them)

- [ ] **Step 1: Create `MiniCard.tsx` with the extracted component**

Create `app/frontend/components/MiniCard.tsx`:

```tsx
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
```

- [ ] **Step 2: Update `ScoringOverlay.tsx` to import `MiniCard`**

In `app/frontend/components/ScoringOverlay.tsx`:

1. Remove the local `SUIT_COLOR` constant (lines 12–15 in the current file).
2. Remove the local `MiniCard` function (lines 17–24 in the current file).
3. Add this import near the top, beneath the existing `import type { ... }` line:

```tsx
import { MiniCard } from "./MiniCard";
```

The rest of `ScoringOverlay.tsx` stays unchanged; the two existing usages of `<MiniCard card={...} />` keep working because the signature is identical.

- [ ] **Step 3: Verify the app still builds and the scoring overlay renders correctly**

Run: `bin/dev`

Then:
1. Start a vs-computer game (`POST /api/games` with `vs_computer: true` via the UI) and play through until the round ends and the scoring overlay appears.
2. Confirm the mini crib-hand cards render with the same size, border, and suit colors as before.

Expected: no TypeScript or Vite errors in the console; scoring overlay mini-cards look unchanged from before the refactor.

- [ ] **Step 4: Commit**

```bash
git add app/frontend/components/MiniCard.tsx app/frontend/components/ScoringOverlay.tsx
git commit -m "extract MiniCard to shared component"
```

---

## Task 2: Add `HowToPlayButton` scaffold with working open/close behavior

Create the floating trigger and a **shell** modal with working dismissal paths. No content yet — just a placeholder heading inside the card. This lets us verify the z-order, positioning, and dismissal behavior in isolation before piling on content.

**Files:**
- Create: `app/frontend/components/HowToPlayButton.tsx`
- Modify: `app/frontend/components/GamePage.tsx` (render the button)

- [ ] **Step 1: Create `HowToPlayButton.tsx` with trigger + shell modal**

Create `app/frontend/components/HowToPlayButton.tsx`:

```tsx
import React, { useState, useEffect, useRef } from "react";

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

        <p className="text-slate-400 text-sm">Content coming next task.</p>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Render `<HowToPlayButton />` in `GamePage.tsx`**

Open `app/frontend/components/GamePage.tsx`.

1. Add this import near the other component imports (around line 13):

```tsx
import { HowToPlayButton } from "./HowToPlayButton";
```

2. The component currently has 5 return points (loading, error, waiting, finished, "joining game", and the main gameplay branch). Add `<HowToPlayButton />` at the end of every returned JSX tree. The simplest approach: wrap each branch's root in a fragment and append the button.

Replace each `return ( ... )` with `return ( <> ... <HowToPlayButton /> </> )`.

Concretely, here are the five branches to update:

**Loading branch** (currently at `GamePage.tsx:35-37`):

```tsx
if (isLoading) {
  return (
    <>
      <div className="min-h-screen bg-slate-950 text-slate-400 flex items-center justify-center">Loading…</div>
      <HowToPlayButton />
    </>
  );
}
```

**Error branch** (currently at `GamePage.tsx:39-46`):

```tsx
if (error || !game) {
  return (
    <>
      <div className="min-h-screen bg-slate-950 text-red-400 flex flex-col items-center justify-center gap-4">
        <p>Could not load game.</p>
        <button onClick={() => navigate("/")} className="text-slate-400 underline text-sm">Back to home</button>
      </div>
      <HowToPlayButton />
    </>
  );
}
```

**Waiting branch** (currently at `GamePage.tsx:48-56`):

```tsx
if (game.status === "waiting") {
  return (
    <>
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-4 p-6">
        <h2 className="text-2xl font-black text-yellow-400">Waiting for opponent…</h2>
        <p className="text-slate-400 text-sm">Send this link to your opponent:</p>
        <CopyLinkButton gameId={game.id} />
      </div>
      <HowToPlayButton />
    </>
  );
}
```

**Finished branch** (currently at `GamePage.tsx:58-88`): wrap the existing JSX in a fragment and append `<HowToPlayButton />` as a sibling after the outer `<div>` closes.

```tsx
if (game.status === "finished") {
  // ... existing confetti / winner logic unchanged ...

  return (
    <>
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 relative overflow-hidden">
        {/* ...existing contents... */}
      </div>
      <HowToPlayButton />
    </>
  );
}
```

**"Joining game" branch** (currently at `GamePage.tsx:90-92`):

```tsx
if (!game.my_slot) {
  return (
    <>
      <div className="min-h-screen bg-slate-950 text-slate-400 flex items-center justify-center">Joining game…</div>
      <HowToPlayButton />
    </>
  );
}
```

**Main gameplay branch** (the big return at the bottom, currently at `GamePage.tsx:152-221`): wrap the outer `<div className="h-dvh bg-slate-950 overflow-hidden">` and append the button:

```tsx
return (
  <>
    <div className="h-dvh bg-slate-950 overflow-hidden">
      {/* ...existing contents unchanged... */}
    </div>
    <HowToPlayButton />
  </>
);
```

- [ ] **Step 3: Verify button shows and modal opens/closes in every game state**

Run: `bin/dev` (if not already running)

Open two browser windows.

1. **Active game:** create a vs-computer game. Button should be visible in the bottom-right. Click it — the modal opens with a placeholder heading. Close it three ways and confirm each works:
   - Press `Escape` — modal closes, focus returns to the trigger.
   - Click the `×` button — modal closes.
   - Click the dimmed backdrop (outside the white-ish card area) — modal closes.
   - Click inside the card — modal stays open.
2. **Waiting state:** create a human-vs-human game but don't join as player 2. Button is visible; modal opens/closes.
3. **Scoring state:** in a vs-computer game, play through until the scoring overlay appears. The help button should sit **behind** the scoring overlay's dark backdrop (not visible above it).
4. **Finished state:** let a vs-computer game end. Button is visible over the confetti; modal opens/closes.

Expected: button visible in every state; modal opens and closes via all three paths; button hidden behind the scoring overlay.

- [ ] **Step 4: Commit**

```bash
git add app/frontend/components/HowToPlayButton.tsx app/frontend/components/GamePage.tsx
git commit -m "add how-to-play button scaffold with modal open/close"
```

---

## Task 3: Add the text content (goal, direction, round flow, scoring rules, winning)

Replace the placeholder content with the five text sections. Scoring rules render inline `MiniCard` examples. Sample board is deferred to Task 4.

**Files:**
- Modify: `app/frontend/components/HowToPlayButton.tsx`

- [ ] **Step 1: Import `MiniCard` and `Card` type**

At the top of `app/frontend/components/HowToPlayButton.tsx`, add imports:

```tsx
import { MiniCard } from "./MiniCard";
import type { Card } from "../types/game";
```

- [ ] **Step 2: Add a module-level helper that builds `MiniCard` props tersely**

Cards are `{ rank, suit, id }`. The id just needs to be unique for React keys — hard-coding strings is fine.

At the top of `HowToPlayButton.tsx`, below the imports, add:

```tsx
const card = (rank: string, suit: string, id: string): Card => ({ rank, suit, id });
```

- [ ] **Step 3: Replace the placeholder paragraph inside `HowToPlayModal` with the five content sections**

Inside `HowToPlayModal`, replace the single `<p className="text-slate-400 text-sm">Content coming next task.</p>` with:

```tsx
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
```

- [ ] **Step 4: Verify the content renders correctly**

Run: `bin/dev`

1. Open the help modal.
2. Confirm all text appears in order: Goal, Your direction, Each round, Scoring, End of round.
3. Confirm the green/blue color words in "Your direction" and "Player 1/2 scores…" match the Board's actual colors (green = you, blue = opponent).
4. Confirm each scoring rule's example mini-cards render with the correct rank and suit colors (hearts/diamonds red, spades/clubs white).
5. Scroll within the modal on a short viewport — inner scroll works, backdrop stays fixed.

Expected: no visual glitches, mini-cards match `ScoringOverlay`'s style, all text readable.

- [ ] **Step 5: Commit**

```bash
git add app/frontend/components/HowToPlayButton.tsx
git commit -m "add how-to-play text content and scoring examples"
```

---

## Task 4: Add the annotated sample board

A static 5×5 grid using `MiniCard`, with row scores on the right in blue, column scores on the bottom in green, and the direction arrow above — matching the live `Board.tsx` layout. Card data is hand-picked; scores are **computed with the real `CribbageHand` class via the Rails console** so they are guaranteed correct.

**Files:**
- Modify: `app/frontend/components/HowToPlayButton.tsx`

- [ ] **Step 1: Pick the 25 sample cards**

Use these exact cards in these exact positions (starter is the center cell):

| | Col 0 | Col 1 | Col 2 | Col 3 | Col 4 |
|---|---|---|---|---|---|
| **Row 0** | 2♠ | 8♥ | K♦ | A♣ | 5♦ |
| **Row 1** | 7♠ | 7♣ | 8♦ | 3♣ | Q♥ |
| **Row 2** | 4♦ | 6♠ | **5♥ (starter)** | 9♦ | 2♣ |
| **Row 3** | 10♣ | J♠ | 2♥ | 6♣ | 3♠ |
| **Row 4** | K♠ | J♥ | 4♠ | Q♣ | A♥ |

All 25 cards are unique. Visual cross check: row 1 has a pair of 7s plus two fifteens (7+8 two ways) = 6 pts — that's the hand we'll highlight in the caption.

- [ ] **Step 2: Compute the real scores via Rails console**

Run: `bin/rails console`

Paste and run this:

```ruby
s = { "rank" => "5", "suit" => "♥", "id" => "starter" }

board = [
  [ {"rank"=>"2","suit"=>"♠","id"=>"r0c0"}, {"rank"=>"8","suit"=>"♥","id"=>"r0c1"}, {"rank"=>"K","suit"=>"♦","id"=>"r0c2"}, {"rank"=>"A","suit"=>"♣","id"=>"r0c3"}, {"rank"=>"5","suit"=>"♦","id"=>"r0c4"} ],
  [ {"rank"=>"7","suit"=>"♠","id"=>"r1c0"}, {"rank"=>"7","suit"=>"♣","id"=>"r1c1"}, {"rank"=>"8","suit"=>"♦","id"=>"r1c2"}, {"rank"=>"3","suit"=>"♣","id"=>"r1c3"}, {"rank"=>"Q","suit"=>"♥","id"=>"r1c4"} ],
  [ {"rank"=>"4","suit"=>"♦","id"=>"r2c0"}, {"rank"=>"6","suit"=>"♠","id"=>"r2c1"}, s,                                                                      {"rank"=>"9","suit"=>"♦","id"=>"r2c3"}, {"rank"=>"2","suit"=>"♣","id"=>"r2c4"} ],
  [ {"rank"=>"10","suit"=>"♣","id"=>"r3c0"}, {"rank"=>"J","suit"=>"♠","id"=>"r3c1"}, {"rank"=>"2","suit"=>"♥","id"=>"r3c2"}, {"rank"=>"6","suit"=>"♣","id"=>"r3c3"}, {"rank"=>"3","suit"=>"♠","id"=>"r3c4"} ],
  [ {"rank"=>"K","suit"=>"♠","id"=>"r4c0"}, {"rank"=>"J","suit"=>"♥","id"=>"r4c1"}, {"rank"=>"4","suit"=>"♠","id"=>"r4c2"}, {"rank"=>"Q","suit"=>"♣","id"=>"r4c3"}, {"rank"=>"A","suit"=>"♥","id"=>"r4c4"} ],
]

row_scores = board.each_with_index.map { |row, i| CribbageHand.new(row, starter: s, is_center: i == 2).score }
col_scores = (0..4).map { |c|
  col = board.map { |row| row[c] }
  CribbageHand.new(col, starter: s, is_center: c == 2).score
}

puts "row_scores = #{row_scores.inspect}"
puts "col_scores = #{col_scores.inspect}"
```

Expected output:

```
row_scores = [4, 6, 9, 4, 9]
col_scores = [0, 7, 4, 2, 7]
```

If the printed arrays do not match exactly, **do not change the numbers below** — the discrepancy means the card data is off (typo, missing card, duplicate id) or the `is_center` flag was miscomputed. Fix the data, not the scores.

- [ ] **Step 3: Add the sample board component and data to `HowToPlayButton.tsx`**

Above the `HowToPlayButton` component in `app/frontend/components/HowToPlayButton.tsx`, add the sample data and the `SampleBoard` component. Replace `ROW_SCORES` and `COL_SCORES` with the numbers you recorded in Step 2:

```tsx
// 5×5 sample board. Center cell is the starter. Display-index rows/cols.
const SAMPLE_BOARD: Card[][] = [
  [ card("2", "♠", "s-r0c0"), card("8", "♥", "s-r0c1"), card("K", "♦", "s-r0c2"), card("A", "♣", "s-r0c3"), card("5", "♦", "s-r0c4") ],
  [ card("7", "♠", "s-r1c0"), card("7", "♣", "s-r1c1"), card("8", "♦", "s-r1c2"), card("3", "♣", "s-r1c3"), card("Q", "♥", "s-r1c4") ],
  [ card("4", "♦", "s-r2c0"), card("6", "♠", "s-r2c1"), card("5", "♥", "s-starter"), card("9", "♦", "s-r2c3"), card("2", "♣", "s-r2c4") ],
  [ card("10", "♣", "s-r3c0"), card("J", "♠", "s-r3c1"), card("2", "♥", "s-r3c2"), card("6", "♣", "s-r3c3"), card("3", "♠", "s-r3c4") ],
  [ card("K", "♠", "s-r4c0"), card("J", "♥", "s-r4c1"), card("4", "♠", "s-r4c2"), card("Q", "♣", "s-r4c3"), card("A", "♥", "s-r4c4") ],
];

const SAMPLE_STARTER_ID = "s-starter";

// Computed via `CribbageHand` — see Task 4 Step 2. Indices are display-rows / display-cols.
const ROW_SCORES: number[] = [4, 6, 9, 4, 9];
const COL_SCORES: number[] = [0, 7, 4, 2, 7];

function SampleBoard() {
  return (
    <div className="flex flex-col gap-1 w-full">
      {/* direction arrows — match live Board */}
      <div className="flex-shrink-0 flex gap-1 items-center">
        <div className="flex gap-1 flex-1 min-w-0">
          {SAMPLE_BOARD[0].map((_, cIdx) => (
            <div key={cIdx} className="flex-1 min-w-0 text-center text-xs text-green-400 leading-none">↓</div>
          ))}
        </div>
        <div className="w-8 ml-1 text-right text-xs text-blue-400 whitespace-nowrap">opp →</div>
      </div>

      {SAMPLE_BOARD.map((row, rIdx) => (
        <div key={rIdx} className="flex items-center gap-1">
          <div className="flex gap-1 flex-1 min-w-0">
            {row.map((c) => {
              const isStarter = c.id === SAMPLE_STARTER_ID;
              return (
                <div
                  key={c.id}
                  className={`flex-1 min-w-0 aspect-[11/14] rounded border ${isStarter ? "border-yellow-400 border-2" : "border-slate-600"} bg-slate-800 flex flex-col items-center justify-center gap-0.5`}
                >
                  <span className="text-slate-100 text-[10px] font-bold leading-none">{c.rank}</span>
                  <span className={`${c.suit === "♥" || c.suit === "♦" ? "text-red-400" : "text-slate-100"} text-[10px] leading-none`}>{c.suit}</span>
                </div>
              );
            })}
          </div>
          {/* row score on the right — blue (opponent's perspective in the modal) */}
          <span className="flex-shrink-0 w-8 text-right text-xs font-mono text-blue-400 ml-1">
            {ROW_SCORES[rIdx]}
          </span>
        </div>
      ))}

      {/* column scores below */}
      <div className="flex-shrink-0 flex gap-1 mt-1 items-center">
        <div className="flex gap-1 flex-1 min-w-0">
          {SAMPLE_BOARD[0].map((_, cIdx) => (
            <div key={cIdx} className="flex-1 min-w-0 text-center text-xs font-mono text-green-400">
              {COL_SCORES[cIdx]}
            </div>
          ))}
        </div>
        <div className="w-8 ml-1 text-right text-xs text-green-400">you</div>
      </div>
    </div>
  );
}
```

Note: the sample board renders its own mini cards inline (not via `MiniCard`) so that the cells can flex to fill available width inside the modal. `MiniCard` is fixed at `w-9 h-12` which is fine for per-rule examples but would overflow inside a 5-column grid on narrow viewports.

- [ ] **Step 4: Render `SampleBoard` inside the modal between the Scoring and End-of-round sections**

In `HowToPlayModal`'s content block, insert a new section between the existing "Scoring" `section` and the "End of round" `section`:

```tsx
{/* 6. Annotated sample board */}
<section>
  <h3 className="text-slate-200 font-bold mb-2">Sample board</h3>
  <SampleBoard />
  <p className="mt-2 text-slate-400 text-xs">
    Row 2 (with the pair of 7s and two fifteens) scores 6 pts. The center cell is the starter, outlined in yellow. The crib is scored separately for whoever owns it that round.
  </p>
</section>
```

- [ ] **Step 5: Verify the sample board renders and the scores printed by Rails match what's on screen**

Run: `bin/dev`

1. Open the help modal.
2. Scroll to the Sample board section.
3. Confirm:
   - 5 green `↓` arrows above the board, `opp →` label to their right.
   - 5×5 grid of mini cards with the center cell outlined in yellow, showing `5♥`.
   - Row scores on the right in blue, column scores on the bottom in green, `you` label to the right.
   - Every score displayed matches the corresponding number in the `ROW_SCORES` / `COL_SCORES` arrays (which match the Rails console output from Step 2).
   - Row 2 (second row from top, 0-indexed = 1) reads `6`. If it doesn't, the picked cards or score array is wrong — do not "fix" the number, re-check the data.
4. On a 375px-wide viewport (phone), confirm the sample board still fits without horizontal scroll.

- [ ] **Step 6: Commit**

```bash
git add app/frontend/components/HowToPlayButton.tsx
git commit -m "add annotated sample board to how-to-play modal"
```

---

## Task 5: Full verification pass and polish

Run every manual test from the spec's Testing section and fix anything that fails.

**Files:** potentially `app/frontend/components/HowToPlayButton.tsx` only — any fixes stay within the new component.

- [ ] **Step 1: Run the complete verification checklist**

Run: `bin/dev`, then walk through each of these:

1. **Open & dim:** click `?`, modal appears centered, page behind is dimmed, trigger is hidden behind the backdrop (z-index correct).
2. **Close via Escape:** modal closes, focus returns to the `?` button (press `Space`/`Enter` afterward — it should reopen the modal, proving focus landed on the trigger).
3. **Close via backdrop:** modal closes.
4. **Close via `×`:** modal closes, focus returns to `?`.
5. **Stays open on inside click:** clicking anywhere inside the card (text, a mini-card, the scoring list) does not close.
6. **Both-perspective direction copy:** open two browser windows; join one as player 1 and the other as player 2; open the help modal in each. Both windows should show the **identical** "Your hands run down ↓ / opponent runs across →" text, and the real board in each window should visually match that description (both players see their hands as columns of the displayed board — because `Board.tsx` transposes for player 2).
7. **z-order during scoring:** play a round to completion; when the scoring overlay appears, the `?` button should be hidden behind its backdrop (not clickable, not visible).
8. **Mobile viewport:** set devtools viewport to 375×667 (iPhone SE). Open the modal. It should fit; the card scrolls internally; the sample board fits without horizontal scroll.
9. **Tab order:** open the modal with keyboard (tab to `?`, press `Enter`). Tab through the modal — the `×` close button should be focusable and activates on `Enter`.
10. **Regression — scoring overlay mini-cards:** play another round to confirm `ScoringOverlay`'s mini crib-hand cards still render identically (the shared `MiniCard` import).

- [ ] **Step 2: If any check fails, fix it inline in `HowToPlayButton.tsx`**

Common failure modes and fixes:
- **Sample board overflows on mobile:** reduce cell font sizes from `text-[10px]` to `text-[9px]`, or reduce gap from `gap-1` to `gap-0.5`.
- **Focus doesn't return to trigger on close:** verify `triggerRef.current?.focus()` is called inside `handleClose` (not only on the modal's internal close).
- **Backdrop click doesn't dismiss:** verify `onClick={onClose}` is on the outer `fixed inset-0` div and `onClick={(e) => e.stopPropagation()}` is on the inner card div.
- **Scoring overlay regresses:** diff `ScoringOverlay.tsx` against HEAD~N — the only intended change is removing the local `MiniCard`/`SUIT_COLOR` and importing from `./MiniCard`.

- [ ] **Step 3: Commit any fixes**

If Step 2 produced changes:

```bash
git add app/frontend/components/HowToPlayButton.tsx
git commit -m "polish how-to-play modal based on manual verification"
```

If no fixes were needed, skip the commit.

---

## Done

The how-to-play button is live in every game state, the modal explains the rules correctly (verified against `cribbage_hand.rb`), and the annotated sample board uses real computed scores from `CribbageHand`. No backend or API changes were made.
