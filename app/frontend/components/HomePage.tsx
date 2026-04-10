import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { setGameId, clearSession, getGames, addGame, removeGame } from "../lib/storage";
import { resetConsumer } from "../lib/cable";

export function HomePage() {
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [createdGameId, setCreatedGameId] = useState<string | null>(null);
  const [games, setGames] = useState(() => getGames());
  const [endingGameId, setEndingGameId] = useState<string | null>(null);

  const endGame = useMutation({
    mutationFn: api.deleteGame,
    onMutate: (gameId) => {
      setEndingGameId(gameId);
      setError(null);
    },
    onSuccess: (_data, gameId) => {
      removeGame(gameId);
      setGames(getGames());
    },
    onError: (e: Error, gameId) => {
      if (e.message === "Game not found") {
        removeGame(gameId);
        setGames(getGames());
      } else {
        setError(e.message);
      }
    },
    onSettled: () => setEndingGameId(null),
  });

  const createGame = useMutation({
    mutationFn: api.createGame,
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      setCreatedGameId(game_id);
      addGame(game_id, false);
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
      addGame(game_id, true);
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
      addGame(game_id, false);
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

      {games.length > 0 && (
        <div className="w-full max-w-sm mt-2">
          <div className="flex items-center gap-2 text-slate-600 text-xs mb-3">
            <hr className="flex-1 border-slate-700" />
            <span>Your Games</span>
            <hr className="flex-1 border-slate-700" />
          </div>
          <div className="flex flex-col gap-2">
            {games.map((g) => (
              <div
                key={g.gameId}
                className="flex items-center justify-between bg-slate-800 border border-slate-700 rounded-lg px-3 py-2"
              >
                <div className="flex flex-col">
                  <span className="font-mono text-yellow-300 text-xs">
                    {g.gameId.slice(0, 8)}
                  </span>
                  <span className="text-slate-500 text-xs">
                    {g.vsComputer ? "vs Computer" : "vs Human"}
                  </span>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      setGameId(g.gameId);
                      navigate(`/game/${g.gameId}`);
                    }}
                    className="rounded bg-slate-700 hover:bg-slate-600 text-slate-100 text-xs font-semibold px-3 py-1"
                  >
                    Rejoin
                  </button>
                  <button
                    onClick={() => endGame.mutate(g.gameId)}
                    disabled={endingGameId === g.gameId}
                    className="rounded bg-red-900 hover:bg-red-800 text-red-200 text-xs font-semibold px-3 py-1 disabled:opacity-50"
                  >
                    {endingGameId === g.gameId ? "Ending…" : "End"}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
