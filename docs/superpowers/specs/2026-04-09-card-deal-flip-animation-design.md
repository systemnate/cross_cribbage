# Card Deal Flip Animation

**Date:** 2026-04-09
**Status:** Approved

## Problem

After an optimistic card placement, `my_next_card` is immediately set to `null` while the server round-trips (~1s). The "Your card" preview shows an empty dashed placeholder during this window — the UI goes quiet with no signal that a new card is coming.

## Approach

Show a face-down card in the preview slot while the server call is pending. When the new card arrives, play a short CSS 3D flip animation to reveal it. The wait becomes anticipation rather than emptiness, and the reveal is satisfying.

## Render States in `CardPreview`

| Condition | Renders |
|---|---|
| `isLoading && !card` | Face-down card (slate back, no rank/suit) |
| `!isLoading && card && isFlipping` | Face-up card + `.card-flip-in` CSS class |
| `!isLoading && card && !isFlipping` | Face-up card (no change from current) |
| `!card && !isLoading` | Empty dashed placeholder (no change — opponent's turn) |

## Component Changes (`CardPreview.tsx`)

Add a `useRef` to track the previous `isLoading` value and a `isFlipping` boolean state:

```tsx
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
```

The face-down card uses the same `w-14 h-20 rounded-lg border-2` shape as the face-up card, with `border-slate-500 bg-slate-800` and a centered `✦` glyph (text-slate-600) — enough to read as "a card is here" without looking interactive.

The face-up card gains the `card-flip-in` class when `isFlipping` is true.

## CSS Changes (`application.css`)

```css
@keyframes card-flip-in {
  0%   { transform: rotateY(90deg); opacity: 0; }
  100% { transform: rotateY(0deg);  opacity: 1; }
}
.card-flip-in {
  animation: card-flip-in 0.25s ease-out forwards;
}
```

## Edge Cases

- **Rollback on error**: If `onError` restores the snapshot (card becomes non-null again without going through a pending→card transition), `isFlipping` remains false and the card renders normally. No stale animation.
- **Discard flow**: Same pending window applies after a discard. The face-down card will show during that wait, which is also correct — the next card is being drawn.
- **Opponent's turn**: When `!card && !isLoading`, the existing dashed placeholder renders unchanged. No face-down card shown.

## Out of Scope

Score placeholder pulse (`—` indicators) — the flip animation draws enough attention away from the score gap. Can be added later if it still feels lacking after testing.

## Files Changed

- `app/frontend/entrypoints/application.css` — add `card-flip-in` keyframe + class
- `app/frontend/components/CardPreview.tsx` — face-down card render state + flip trigger logic
