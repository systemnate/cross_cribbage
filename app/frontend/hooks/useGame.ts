// app/frontend/hooks/useGame.ts
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { GameState } from "../types/game";

export function useGame(gameId: string | null) {
  return useQuery<GameState>({
    queryKey: ["game", gameId],
    queryFn: () => api.getGame(gameId!),
    enabled: !!gameId,
    staleTime: Infinity,
    refetchOnWindowFocus: false,
  });
}
