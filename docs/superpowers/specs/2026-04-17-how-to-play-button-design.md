# How-To-Play Button & Modal — Design

**Date:** 2026-04-17
**Scope:** Frontend-only. A floating trigger button on `GamePage` that opens a modal explaining how to play Cross Cribbage, including an annotated sample 5×5 board.

## Goal

Let a new (or rusty) player open an in-game reference that covers the goal, the direction they're playing, the core scoring rules, the crib-discard requirement, and a worked-out example board — without leaving the game view.

## Non-goals

- No persistence ("seen it" flag, do-not-show-again, etc.)
- No i18n / multi-language support
- No rules link on `HomePage` (this spec only covers the in-game button)
- No interactive tutorial or click-to-reveal scoring walkthrough
- No animated open/close transitions beyond what Tailwind provides by default

## User experience

### Trigger button

- A small circular floating button anchored to the bottom-right of the viewport.
- Visible on `GamePage` in every status (waiting / active / scoring / finished), so a player can check rules at any time.
- Shows a "?" glyph. Accessible label "How to play".
- Sits at `z-40`, below the scoring modal (`z-50`), so it never floats on top of the scoring overlay.
- Styling matches the existing slate palette: slate-800 bg, slate-600 border, slate-200 glyph, subtle hover state.

### Modal

- Opens on button click. Uses the same pattern as `ScoringOverlay`:
  `fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4`
  with a centered `bg-slate-900 border border-slate-700 rounded-xl` card.
- Card is scrollable: `max-h-[90vh] overflow-y-auto`, max width ~`max-w-lg`.
- Dismissible three ways:
  1. Close "×" button in the top-right of the card
  2. `Escape` key
  3. Clicking the backdrop (the dimmed area outside the card)
- Clicking inside the card does **not** close it (event propagation stopped on the card element).

### Modal content (top → bottom)

1. **Heading:** "How to play Cross Cribbage"

2. **Goal:** one line — "First to 31 pegging points wins."

3. **Your direction:** one paragraph —
   "Your hands run **down** ↓ (green). Your opponent's hands run **across** → (blue). When the board fills, every column you see is one of your 5-card hands."
   This copy is static for both players — `Board.tsx` transposes the board for player 2 so each player always sees their hands as columns. Colors match `Board.tsx` (green = you, blue = opponent).

4. **Each round:** four short bullets
   - 14 cards are dealt to each player.
   - The center cell is the starter card (shared by both players).
   - **Discard 2 cards to the crib** before you've placed enough cards to fill the board — use the purple *Discard to crib* button on your card preview.
   - You and your opponent place cards one at a time, taking turns, until all 24 empty cells are filled.

5. **Scoring rules** — compact list, each with a tiny `MiniCard` example rendered inline. Same `MiniCard` style/size as the one in `ScoringOverlay` (≈ `w-9 h-12`).
   - Each row and each column is a 5-card hand. The center cell holds the starter, so the **middle row and middle column** contain the starter as one of their 5 cards; the other rows/columns do not.
   - **Player 1 scores all 5 columns. Player 2 scores all 5 rows.** The crib is a separate 4-card hand plus the starter, scored only for its owner.
   - **Fifteens — 2 pts each:** any combination of cards in the hand that sums to 15 (face cards count as 10, Ace = 1).
     Example: `5♥` + `10♣`
   - **Pair — 2 pts** (same rank). **Three of a kind — 6 pts. Four of a kind — 12 pts.**
     Example: `7♥` + `7♠`
   - **Run — 1 pt per card (minimum 3):** consecutive ranks, any suit.
     Example: `4♦` + `5♣` + `6♥`
   - **Flush — 5 pts:** all 5 cards in the hand share a suit. (In the crib, all 4 crib cards *and* the starter must match — strict flush.)
   - **Nobs — 1 pt:** only scored in the **middle row and middle column** (the two hands that contain the starter). If one of the other 4 cards in that hand is the Jack matching the starter's suit, it's worth 1 pt.
   - **Nibs — 2 pts:** the starter card itself is a Jack; awarded immediately to the crib owner at the start of the round.

6. **Annotated sample board:** a full 5×5 grid with the starter in the center and 24 other cards filling the rest.
   - Rendered with the same layout conventions as live `Board.tsx`: row scores on the right in blue, column scores on the bottom in green, direction arrow above.
   - Uses `MiniCard`-sized cells (smaller than the live board) so the whole 5×5 fits comfortably in the modal.
   - Static data — the cards and scores are hard-coded in the component.
   - Under the board: one caption sentence, e.g. "In this example, row 2 scores 6 pts (a pair plus a run of 3). The crib is scored separately and goes to whoever owns it this round."

7. **End of round / winning:** one line — "The player who scores more that round pegs the point difference. First to 31 total pegging points wins the game."

## Architecture

### New file: `app/frontend/components/HowToPlayButton.tsx`

Single file, two React components:

- `HowToPlayButton` — the exported component. No props. Owns the open/closed state via `useState<boolean>`. Renders the floating trigger button. When open, renders `<HowToPlayModal onClose={...} />`.

- `HowToPlayModal` — internal component. Props: `{ onClose }`.
  - Registers a `keydown` listener for `Escape` in a `useEffect` (cleaned up on unmount).
  - Backdrop `div` has `onClick={onClose}`; the card `div` inside has `onClick={e => e.stopPropagation()}`.
  - Renders all 7 content sections above.

- A small internal `MiniCard` component (or reuse the one from `ScoringOverlay` by extracting it — see "Shared MiniCard" below).

- A small internal `SampleBoard` component that renders the hard-coded 5×5 grid with row/column scores and arrows. Keeps the main component readable.

### Touched file: `app/frontend/components/GamePage.tsx`

Add `<HowToPlayButton />` as a sibling of the main container — at the top level of every returned JSX branch (loading, error, waiting, finished, joining, and the main gameplay branch). Because the button uses `fixed` positioning, where it sits in the DOM doesn't affect layout, but keeping it inside the returned JSX (not wrapping everything in a fragment) is cleanest.

Simplest implementation: extract the rendered content of each branch into a local variable `content`, then `return (<>{content}<HowToPlayButton /></>)` once at the bottom. Or add the button inline in each branch if the duplication reads better — either is fine, implementer's call.

### Shared `MiniCard`

`ScoringOverlay.tsx` already defines a `MiniCard` component (`app/frontend/components/ScoringOverlay.tsx:17`). Rather than duplicate it, extract it to `app/frontend/components/MiniCard.tsx` and import it from both `ScoringOverlay` and `HowToPlayButton`. This is a small, targeted refactor that serves the current goal (re-use the exact same visual for the scoring examples and the sample board).

### Data: static cards

The sample board uses hard-coded `Card` objects. `Card` is defined in `app/frontend/types/game.ts`. The sample data lives as a module-level constant inside `HowToPlayButton.tsx` (not exported, not in `types/`), because it's only used by the help modal.

One chosen sample board (implementer picks exact cards; the shape below is indicative):

```
                ↓   ↓   ↓   ↓   ↓      opp →
            ┌───┬───┬───┬───┬───┐
  row 1 ──▶ │ . │ . │ . │ . │ . │ ── score
            ├───┼───┼───┼───┼───┤
  row 2 ──▶ │ . │ . │ . │ . │ . │ ── 6
            ├───┼───┼───┼───┼───┤
  row 3 ──▶ │ . │ . │ ★ │ . │ . │ ── score   ★ = starter
            ├───┼───┼───┼───┼───┤
  row 4 ──▶ │ . │ . │ . │ . │ . │ ── score
            ├───┼───┼───┼───┼───┤
  row 5 ──▶ │ . │ . │ . │ . │ . │ ── score
            └───┴───┴───┴───┴───┘
             col col col col col
             scr scr scr scr scr                       you
```

The concrete cards and scores are the implementer's choice, but the goal is to have at least one row and one column whose score is non-trivial (shows a pair + run, or a 15 + pair, etc.) so the caption sentence reads naturally.

## State / data flow

- No server calls.
- No route change.
- State: a single `open: boolean` in `HowToPlayButton`. No context, no global store.
- No props — direction copy is the same for both players because the board is always displayed with your hands as columns (see "Your direction").

## Accessibility

- Button has `aria-label="How to play"`.
- Modal card uses `role="dialog"` and `aria-modal="true"`.
- Escape key closes the modal.
- When the modal is open, focus moves to the close button (use a `ref` + `useEffect`). When closed, focus returns to the trigger (use a `ref` on the trigger).
- The "?" glyph is decorative; the `aria-label` provides the name.
- No focus trap is required beyond moving focus in and out — the modal is short and keyboard users can always press `Escape`.

## Styling notes

- Follow the existing Tailwind conventions in the project (slate/yellow/green/blue palette, rounded-xl cards, `border-slate-700`, etc.).
- No new Tailwind classes or plugins.
- Reuse `SUIT_COLOR` by either importing it from `MiniCard` (after extraction) or replicating it locally.

## Testing

The frontend has no JS test suite (per `CLAUDE.md`). Manual verification is the plan:

1. Load a game, click the "?" button — modal appears centered and the page behind it is dimmed.
2. Press `Escape`, click outside the card, and click the "×" — each dismisses the modal.
3. Click inside the modal card — it does **not** close.
4. Join as player 1 and as player 2 in two browser windows — verify the "Your direction" copy reads correctly from both perspectives (it is the same static text for both, and should match what each player actually sees on their displayed board).
5. While in the scoring overlay, confirm the "?" button is hidden behind it (z-order correct) and that the scoring overlay still functions.
6. On a narrow mobile viewport, confirm the modal scrolls internally and the sample board remains legible.
7. Verify the extracted `MiniCard` still renders identically inside `ScoringOverlay` (no regression there).

No new backend tests — this is a frontend-only change.

## Out of scope / future

- A first-time popup that auto-opens once for new players.
- A "how to play" link on the `HomePage`.
- Translating the rules copy.
- An interactive sample board where the player can hover cells to highlight a scoring combo.
