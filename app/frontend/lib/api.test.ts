import { describe, it, expect, beforeEach, vi } from "vitest";
import { api } from "./api";

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

function jsonResponse(body: unknown, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: status === 200 ? "OK" : "Error",
    json: () => Promise.resolve(body),
  };
}

beforeEach(() => {
  mockFetch.mockReset();
});

describe("api.createGame", () => {
  it("POSTs to /api/games with vs_computer option", async () => {
    mockFetch.mockResolvedValue(jsonResponse({ game_id: "abc" }));
    const result = await api.createGame({ vs_computer: true });
    expect(result).toEqual({ game_id: "abc" });
    expect(mockFetch).toHaveBeenCalledWith("/api/games", {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ vs_computer: true }),
    });
  });
});

describe("api.joinGame", () => {
  it("POSTs to /api/games/:id/join", async () => {
    mockFetch.mockResolvedValue(jsonResponse({ game_id: "abc" }));
    await api.joinGame("abc");
    expect(mockFetch).toHaveBeenCalledWith(
      "/api/games/abc/join",
      expect.objectContaining({ method: "POST" })
    );
  });
});

describe("api.getGame", () => {
  it("GETs /api/games/:id", async () => {
    const gameState = { id: "abc", status: "active" };
    mockFetch.mockResolvedValue(jsonResponse(gameState));
    const result = await api.getGame("abc");
    expect(result).toEqual(gameState);
    expect(mockFetch).toHaveBeenCalledWith(
      "/api/games/abc",
      expect.objectContaining({ method: "GET", body: undefined })
    );
  });
});

describe("api.placeCard", () => {
  it("POSTs row and col", async () => {
    mockFetch.mockResolvedValue(jsonResponse({ id: "abc" }));
    await api.placeCard("abc", 1, 3);
    expect(mockFetch).toHaveBeenCalledWith(
      "/api/games/abc/place_card",
      expect.objectContaining({
        body: JSON.stringify({ row: 1, col: 3 }),
      })
    );
  });
});

describe("api.discardToCrib", () => {
  it("POSTs to discard endpoint", async () => {
    mockFetch.mockResolvedValue(jsonResponse({ id: "abc" }));
    await api.discardToCrib("abc");
    expect(mockFetch).toHaveBeenCalledWith(
      "/api/games/abc/discard_to_crib",
      expect.objectContaining({ method: "POST" })
    );
  });
});

describe("error handling", () => {
  it("throws with server error message", async () => {
    mockFetch.mockResolvedValue(jsonResponse({ error: "Not your turn" }, 422));
    await expect(api.placeCard("abc", 0, 0)).rejects.toThrow("Not your turn");
  });

  it("falls back to statusText when body has no error field", async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
      statusText: "Internal Server Error",
      json: () => Promise.reject(),
    });
    await expect(api.getGame("abc")).rejects.toThrow("Internal Server Error");
  });
});
