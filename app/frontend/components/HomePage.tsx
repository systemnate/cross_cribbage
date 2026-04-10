import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { setGameId, clearSession } from "../lib/storage";
import { resetConsumer } from "../lib/cable";

export function HomePage() {
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [createdGameId, setCreatedGameId] = useState<string | null>(null);

  const createGame = useMutation({
    mutationFn: api.createGame,
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      setCreatedGameId(game_id);
    },
    onError: (e: Error) => setError(e.message),
  });

  const playComputer = useMutation({
    mutationFn: () => api.createGame({ vs_computer: true }),
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  const joinGame = useMutation({
    mutationFn: () => api.joinGame(joinId.trim()),
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  if (createdGameId) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
        <h1 className="text-3xl font-black text-green-400">Game created!</h1>
        <p className="text-slate-400 text-sm">Share this ID with your opponent:</p>
        <div className="bg-slate-800 border border-slate-600 rounded-lg px-6 py-3 font-mono text-yellow-300 text-sm select-all">
          {createdGameId}
        </div>
        <p className="text-slate-500 text-xs">Waiting for opponent to join…</p>
        <button
          onClick={() => navigate(`/game/${createdGameId}`)}
          className="rounded-lg bg-slate-700 hover:bg-slate-600 text-slate-100 font-semibold px-5 py-2 text-sm"
        >
          Go to game
        </button>
      </div>
    );
  }

  const anyPending = createGame.isPending || playComputer.isPending || joinGame.isPending;

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
      <h1 className="text-4xl font-black tracking-wide text-yellow-400">Cross Cribbage</h1>
      <p className="text-slate-400 text-sm">Real-time two-player cribbage on a 5×5 board</p>

      {error && <p className="text-red-400 text-xs">{error}</p>}

      <div className="flex flex-col gap-4 w-full max-w-sm">
        <div className="flex gap-2">
          <button
            onClick={() => createGame.mutate({})}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-yellow-400 hover:bg-yellow-300 disabled:opacity-50 text-slate-900 font-bold py-3 text-sm transition-colors"
          >
            {createGame.isPending ? "Creating…" : "Start New Game"}
          </button>
          <button
            onClick={() => playComputer.mutate()}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white font-bold py-3 text-sm transition-colors"
          >
            {playComputer.isPending ? "Starting…" : "Play Computer"}
          </button>
        </div>

        <div className="flex items-center gap-2 text-slate-600 text-xs">
          <hr className="flex-1 border-slate-700" /><span>or</span><hr className="flex-1 border-slate-700" />
        </div>

        <div className="flex gap-2">
          <input
            type="text"
            placeholder="Paste Game ID"
            value={joinId}
            onChange={(e) => setJoinId(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && joinGame.mutate()}
            className="flex-1 rounded-lg bg-slate-800 border border-slate-700 text-slate-100 text-sm px-3 py-2 focus:outline-none focus:border-yellow-400"
          />
          <button
            onClick={() => joinGame.mutate()}
            disabled={anyPending || !joinId.trim()}
            className="rounded-lg bg-slate-700 hover:bg-slate-600 disabled:opacity-50 text-slate-100 font-semibold px-4 py-2 text-sm"
          >
            {joinGame.isPending ? "Joining…" : "Join"}
          </button>
        </div>
      </div>
    </div>
  );
}
