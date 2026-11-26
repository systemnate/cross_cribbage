import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import "@testing-library/jest-dom";
import React from "react";
import { CardPreview } from "./CardPreview";
import type { Card } from "../types/game";

const card: Card = { rank: "9", suit: "♣", id: "9♣" };

const baseProps = {
  card,
  deckSize: 13,
  isMyTurn: true,
  onDiscard: vi.fn(),
  canDiscard: true,
  isLoading: false,
};

function statusSlot(container: HTMLElement): HTMLElement {
  const slot = container.querySelector<HTMLElement>("[data-testid='card-preview-status']");
  if (!slot) throw new Error("status slot not rendered");
  return slot;
}

/** The slot's layout-relevant shape: every child's tag and classes, minus the visibility toggle. */
function slotShape(container: HTMLElement): string[] {
  return Array.from(statusSlot(container).children).map(
    (el) => `${el.tagName}.${el.className.split(/\s+/).filter((c) => c && c !== "invisible").sort().join(".")}`
  );
}

describe("CardPreview", () => {
  describe("layout stability across turns", () => {
    // The side panel has no fixed size and the board fills whatever space is
    // left beside (desktop) or above (mobile) it. If the status line under the
    // card swaps between differently-sized elements on turn change, the whole
    // board resizes for the duration of the opponent's turn.
    const states = {
      myTurnCanDiscard: { isMyTurn: true, canDiscard: true },
      myTurnDiscardsDone: { isMyTurn: true, canDiscard: false },
      opponentsTurn: { isMyTurn: false, canDiscard: true },
      opponentsTurnLoading: { isMyTurn: false, canDiscard: true, card: null, isLoading: true },
    };

    it("renders the same status slot shape in every turn state", () => {
      const shapes = Object.values(states).map((overrides) => {
        const { container } = render(<CardPreview {...baseProps} {...overrides} />);
        const shape = slotShape(container);
        container.remove();
        return shape;
      });

      expect(shapes[0]).toHaveLength(2);
      for (const shape of shapes) expect(shape).toEqual(shapes[0]);
    });
  });

  describe("status slot visibility", () => {
    it("shows the discard button and hides the waiting note on my turn", () => {
      const onDiscard = vi.fn();
      render(<CardPreview {...baseProps} onDiscard={onDiscard} />);

      const button = screen.getByRole("button", { name: "Discard to crib" });
      expect(button).not.toHaveClass("invisible");
      expect(button).toBeEnabled();
      fireEvent.click(button);
      expect(onDiscard).toHaveBeenCalledTimes(1);

      const note = screen.getByText(/Waiting…/);
      expect(note).toHaveClass("invisible");
      expect(note).toHaveAttribute("aria-hidden", "true");
    });

    it("hides and disables the discard button and shows the waiting note on the opponent's turn", () => {
      const onDiscard = vi.fn();
      const { container } = render(<CardPreview {...baseProps} isMyTurn={false} onDiscard={onDiscard} />);

      const button = statusSlot(container).querySelector("button")!;
      expect(button).toHaveClass("invisible");
      expect(button).toBeDisabled();
      expect(button).toHaveAttribute("aria-hidden", "true");
      expect(button).toHaveAttribute("tabindex", "-1");

      const note = screen.getByText(/Waiting…/);
      expect(note).not.toHaveClass("invisible");
      expect(note).toHaveAttribute("aria-hidden", "false");
    });

    it("hides the discard button once both crib discards are used", () => {
      const { container } = render(<CardPreview {...baseProps} canDiscard={false} />);
      const button = statusSlot(container).querySelector("button")!;
      expect(button).toHaveClass("invisible");
      expect(button).toBeDisabled();
    });
  });
});
