// app/frontend/lib/storage.ts
const GAME_KEY = "ccg_game_id";

export const getGameId     = (): string | null => localStorage.getItem(GAME_KEY);
export const setGameId     = (id: string): void => { localStorage.setItem(GAME_KEY, id); };
export const clearSession  = (): void => { localStorage.removeItem(GAME_KEY); };

const GAMES_KEY = "ccg_games";
const TWO_HOURS_MS = 2 * 60 * 60 * 1000;

export interface StoredGame {
  gameId: string;
  vsComputer: boolean;
  createdAt: number;
}

export function getGames(): StoredGame[] {
  const raw = localStorage.getItem(GAMES_KEY);
  if (!raw) return [];
  try {
    const games: StoredGame[] = JSON.parse(raw);
    const fresh = games.filter((g) => Date.now() - g.createdAt < TWO_HOURS_MS);
    if (fresh.length !== games.length) {
      localStorage.setItem(GAMES_KEY, JSON.stringify(fresh));
    }
    return fresh;
  } catch {
    localStorage.removeItem(GAMES_KEY);
    return [];
  }
}

export function addGame(gameId: string, vsComputer: boolean): void {
  const games = getGames().filter((g) => g.gameId !== gameId);
  games.push({ gameId, vsComputer, createdAt: Date.now() });
  localStorage.setItem(GAMES_KEY, JSON.stringify(games));
}

export function removeGame(gameId: string): void {
  const games = getGames().filter((g) => g.gameId !== gameId);
  localStorage.setItem(GAMES_KEY, JSON.stringify(games));
}
