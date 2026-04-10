// app/frontend/types/game.ts

export interface Card {
  rank: string;
  suit: string;
  id: string;
}

export interface CribSize {
  player1: number;
  player2: number;
}

export interface DeckSize {
  player1: number;
  player2: number;
}

// Full state returned by HTTP endpoints (includes private fields)
export interface GameState {
  id: string;
  status: "waiting" | "active" | "scoring" | "finished";
  current_turn: "player1" | "player2" | null;
  round: number;
  crib_owner: "player1" | "player2" | null;
  board: (Card | null)[][];          // 5×5, Player 1 coordinate space
  starter_card: Card | null;
  row_scores: (number | null)[];     // length 5
  col_scores: (number | null)[];     // length 5
  crib_score: number | null;
  crib_size: CribSize;
  deck_size: DeckSize;
  player1_peg: number;
  player2_peg: number;
  winner_slot: "player1" | "player2" | null;
  player1_confirmed_scoring: boolean;
  player2_confirmed_scoring: boolean;
  crib_hand: Card[] | null;
  vs_computer: boolean;
  // Private — only included in HTTP responses, never in broadcasts
  my_slot: "player1" | "player2" | null;
  my_next_card: Card | null;
}

// Broadcast payload — excludes private player fields, but includes per-player next cards
export type GameChannelMessage = Omit<GameState, "id" | "my_slot" | "my_next_card"> & {
  type: "game_state";
  player1_next_card: Card | null;
  player2_next_card: Card | null;
};

export interface CreateGameResponse {
  game_id: string;
}
