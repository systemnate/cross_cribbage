// app/frontend/lib/api.ts
import type { GameState, CreateGameResponse } from "../types/game";

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`/api${path}`, {
    method,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error ?? "Request failed");
  }

  return res.json() as Promise<T>;
}

export const api = {
  createGame: (options?: { vs_computer?: boolean }): Promise<CreateGameResponse> =>
    request("POST", "/games", options),

  joinGame: (id: string): Promise<CreateGameResponse> =>
    request("POST", `/games/${id}/join`),

  getGame: (id: string): Promise<GameState> =>
    request("GET", `/games/${id}`),

  placeCard: (id: string, row: number, col: number): Promise<GameState> =>
    request("POST", `/games/${id}/place_card`, { row, col }),

  discardToCrib: (id: string): Promise<GameState> =>
    request("POST", `/games/${id}/discard_to_crib`),

  confirmRound: (id: string): Promise<GameState> =>
    request("POST", `/games/${id}/confirm_round`),

  deleteGame: (id: string): Promise<{ ok: boolean }> =>
    request("DELETE", `/games/${id}`),
};
