// app/frontend/hooks/useGameChannel.ts
import { useEffect, useRef } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { getConsumer } from "../lib/cable";
import type { GameChannelMessage, GameState } from "../types/game";

export function useGameChannel(
  gameId: string | null,
  onOpponentCardPlayed?: (row: number, col: number) => void
): void {
  const queryClient = useQueryClient();
  const callbackRef = useRef(onOpponentCardPlayed);
  callbackRef.current = onOpponentCardPlayed;

  useEffect(() => {
    if (!gameId) return;

    const consumer = getConsumer();
    const subscription = consumer.subscriptions.create(
      { channel: "GameChannel", game_id: gameId },
      {
        received(data: GameChannelMessage) {
          const old = queryClient.getQueryData<GameState>(["game", gameId]);
          if (!old) {
            // Broadcast arrived before the initial fetch completed; trigger a refetch.
            queryClient.invalidateQueries({ queryKey: ["game", gameId] });
            return;
          }

          // Detect cells that went from null → card while it was the opponent's turn
          if (callbackRef.current && old.my_slot && old.current_turn && old.current_turn !== old.my_slot) {
            for (let r = 0; r < data.board.length; r++) {
              for (let c = 0; c < (data.board[r]?.length ?? 0); c++) {
                if (!old.board[r]?.[c] && data.board[r]?.[c]) {
                  callbackRef.current(r, c);
                }
              }
            }
          }

          const roundChanged = data.round !== old.round;

          // On a new round, use the broadcast's per-player next card; otherwise preserve cached value
          const nextCard = roundChanged
            ? (old.my_slot === "player1" ? data.player1_next_card : data.player2_next_card)
            : old.my_next_card;

          // Merge broadcast fields; preserve private fields from HTTP cache
          const updated: GameState = {
            ...old,
            status:       data.status,
            current_turn: data.current_turn,
            round:        data.round,
            crib_owner:   data.crib_owner,
            board:        data.board,
            starter_card: data.starter_card,
            row_scores:   data.row_scores,
            col_scores:   data.col_scores,
            crib_score:   data.crib_score,
            crib_size:    data.crib_size,
            deck_size:    data.deck_size,
            player1_peg:  data.player1_peg,
            player2_peg:  data.player2_peg,
            winner_slot:  data.winner_slot,
            player1_confirmed_scoring: data.player1_confirmed_scoring,
            player2_confirmed_scoring: data.player2_confirmed_scoring,
            crib_hand:    data.crib_hand,
            // Always preserve — not in broadcast
            my_slot:      old.my_slot,
            my_next_card: nextCard,
          };

          queryClient.setQueryData(["game", gameId], updated);
        },
      }
    );

    return () => { subscription.unsubscribe(); };
  }, [gameId, queryClient]);
}
