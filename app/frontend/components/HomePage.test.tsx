import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import "@testing-library/jest-dom";
import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router";
import { HomePage } from "./HomePage";

vi.mock("../lib/storage", () => ({
  setGameId: vi.fn(),
  clearSession: vi.fn(),
  getGames: () => [],
  addGame: vi.fn(),
  removeGame: vi.fn(),
}));

function renderHome() {
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <MemoryRouter>
        <HomePage />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe("HomePage", () => {
  it("shows the Thanksgiving greeting with the turkey illustration", () => {
    renderHome();
    expect(screen.getByText("Happy Thanksgiving!")).toBeInTheDocument();
    expect(screen.getByRole("img", { name: "Turkey" })).toBeInTheDocument();
  });
});
