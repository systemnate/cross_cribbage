// app/frontend/lib/storage.ts
const GAME_KEY = "ccg_game_id";

export const getGameId     = (): string | null => localStorage.getItem(GAME_KEY);
export const setGameId     = (id: string): void => { localStorage.setItem(GAME_KEY, id); };
export const clearSession  = (): void => { localStorage.removeItem(GAME_KEY); };
