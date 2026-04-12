import React, { useEffect, useRef, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { clearSession, setGameId, addGame } from "../lib/storage";
import { resetConsumer } from "../lib/cable";

export function JoinPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const joined = useRef(false);

  useEffect(() => {
    if (!id || joined.current) return;
    joined.current = true;

    clearSession();
    resetConsumer();

    api.joinGame(id).then(
      ({ game_id }) => {
        setGameId(game_id);
        addGame(game_id, false);
        navigate(`/game/${game_id}`, { replace: true });
      },
      (err: Error) => setError(err.message),
    );
  }, [id, navigate]);

  if (error) {
    return (
      <div className="min-h-screen bg-slate-950 text-red-400 flex flex-col items-center justify-center gap-4">
        <p>{error}</p>
        <button onClick={() => navigate("/")} className="text-slate-400 underline text-sm">
          Back to home
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-400 flex items-center justify-center">
      Joining game…
    </div>
  );
}
