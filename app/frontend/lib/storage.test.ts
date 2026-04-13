import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  getGameId,
  setGameId,
  clearSession,
  getGames,
  addGame,
  removeGame,
} from "./storage";

beforeEach(() => {
  localStorage.clear();
});

describe("session helpers", () => {
  it("getGameId returns null when nothing stored", () => {
    expect(getGameId()).toBeNull();
  });

  it("setGameId / getGameId round-trips", () => {
    setGameId("abc-123");
    expect(getGameId()).toBe("abc-123");
  });

  it("clearSession removes the game id", () => {
    setGameId("abc-123");
    clearSession();
    expect(getGameId()).toBeNull();
  });
});

describe("games list", () => {
  it("returns empty array when nothing stored", () => {
    expect(getGames()).toEqual([]);
  });

  it("addGame stores a game and getGames retrieves it", () => {
    addGame("g1", false);
    const games = getGames();
    expect(games).toHaveLength(1);
    expect(games[0].gameId).toBe("g1");
    expect(games[0].vsComputer).toBe(false);
  });

  it("addGame replaces a duplicate game id", () => {
    addGame("g1", false);
    addGame("g1", true);
    const games = getGames();
    expect(games).toHaveLength(1);
    expect(games[0].vsComputer).toBe(true);
  });

  it("removeGame removes the specified game", () => {
    addGame("g1", false);
    addGame("g2", true);
    removeGame("g1");
    const games = getGames();
    expect(games).toHaveLength(1);
    expect(games[0].gameId).toBe("g2");
  });

  it("filters out games older than 2 hours", () => {
    const threeHoursAgo = Date.now() - 3 * 60 * 60 * 1000;
    localStorage.setItem(
      "ccg_games",
      JSON.stringify([
        { gameId: "old", vsComputer: false, createdAt: threeHoursAgo },
        { gameId: "new", vsComputer: true, createdAt: Date.now() },
      ])
    );
    const games = getGames();
    expect(games).toHaveLength(1);
    expect(games[0].gameId).toBe("new");
  });

  it("clears storage and returns [] on corrupt JSON", () => {
    localStorage.setItem("ccg_games", "not-json");
    expect(getGames()).toEqual([]);
    expect(localStorage.getItem("ccg_games")).toBeNull();
  });
});
