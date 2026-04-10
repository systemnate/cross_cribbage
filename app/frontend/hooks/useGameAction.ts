import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { GameState } from "../types/game";

interface GameMutation {
  action: () => Promise<GameState>;
  optimistic?: (old: GameState) => Partial<GameState>;
}

export function useGameAction(gameId: string | null) {
  const queryClient = useQueryClient();

  return useMutation<GameState, Error, GameMutation, { snapshot: GameState | undefined }>({
    mutationFn: ({ action }) => action(),
    onMutate: async ({ optimistic }) => {
      if (!gameId) return { snapshot: undefined };
      const snapshot = queryClient.getQueryData<GameState>(["game", gameId]);
      if (optimistic && snapshot) {
        await queryClient.cancelQueries({ queryKey: ["game", gameId] });
        queryClient.setQueryData<GameState>(["game", gameId], {
          ...snapshot,
          ...optimistic(snapshot),
        });
      }
      return { snapshot };
    },
    onError: (_err, _vars, context) => {
      if (gameId && context?.snapshot) {
        queryClient.setQueryData(["game", gameId], context.snapshot);
      }
    },
    onSuccess: (data) => {
      if (gameId) queryClient.setQueryData(["game", gameId], data);
    },
  });
}
