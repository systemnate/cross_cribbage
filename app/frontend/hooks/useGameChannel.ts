// app/frontend/hooks/useGameChannel.ts
import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { getConsumer } from "../lib/cable";
import { getToken } from "../lib/storage";
import type { GameChannelMessage, GameState } from "../types/game";

export function useGameChannel(gameId: string | null): void {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!gameId) return;

    const consumer = getConsumer();
    const subscription = consumer.subscriptions.create(
      { channel: "GameChannel", game_id: gameId, token: getToken() },
      {
        received(data: GameChannelMessage) {
          queryClient.setQueryData<GameState>(["game", gameId], (old) => {
            if (!old) return old;

            const roundChanged = data.round !== old.round;

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
              // Always preserve — not in broadcast
              my_slot:      old.my_slot,
              my_next_card: old.my_next_card,
            };

            // New round means our cached next card is stale — refetch
            if (roundChanged) {
              setTimeout(() => {
                queryClient.invalidateQueries({ queryKey: ["game", gameId] });
              }, 0);
            }

            return updated;
          });
        },
      }
    );

    return () => { subscription.unsubscribe(); };
  }, [gameId, queryClient]);
}
