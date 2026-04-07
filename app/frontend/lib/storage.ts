// app/frontend/lib/storage.ts
const TOKEN_KEY = "ccg_player_token";
const GAME_KEY  = "ccg_game_id";

export const getToken  = (): string | null => localStorage.getItem(TOKEN_KEY);
export const setToken  = (t: string): void  => { localStorage.setItem(TOKEN_KEY, t); };
export const getGameId = (): string | null => localStorage.getItem(GAME_KEY);
export const setGameId = (id: string): void => { localStorage.setItem(GAME_KEY, id); };
export const clearSession = (): void => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(GAME_KEY);
};
