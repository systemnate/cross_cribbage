// app/frontend/hooks/useGameAction.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { GameState } from "../types/game";

export function useGameAction(gameId: string | null) {
  const queryClient = useQueryClient();

  return useMutation<GameState, Error, () => Promise<GameState>>({
    mutationFn: (fn) => fn(),
    onSuccess: (data) => {
      if (gameId) queryClient.setQueryData(["game", gameId], data);
    },
  });
}
