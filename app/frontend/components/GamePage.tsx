import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useGame } from "../hooks/useGame";
import { useGameChannel } from "../hooks/useGameChannel";
import { useGameAction } from "../hooks/useGameAction";
import { api } from "../lib/api";
import { getGameId } from "../lib/storage";
import { Board } from "./Board";
import { PegBoard } from "./PegBoard";
import { CardPreview } from "./CardPreview";
import { CribArea } from "./CribArea";
import { ScoringOverlay } from "./ScoringOverlay";

export function GamePage() {
  const { id: urlId } = useParams<{ id: string }>();
  const navigate       = useNavigate();
  const gameId         = urlId ?? getGameId() ?? null;

  const { data: game, isLoading, error } = useGame(gameId);
  useGameChannel(gameId);
  const action = useGameAction(gameId ?? "");

  if (isLoading) {
    return <div className="min-h-screen bg-slate-950 text-slate-400 flex items-center justify-center">Loading…</div>;
  }

  if (error || !game) {
    return (
      <div className="min-h-screen bg-slate-950 text-red-400 flex flex-col items-center justify-center gap-4">
        <p>Could not load game.</p>
        <button onClick={() => navigate("/")} className="text-slate-400 underline text-sm">Back to home</button>
      </div>
    );
  }

  if (game.status === "waiting") {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-4 p-6">
        <h2 className="text-2xl font-black text-yellow-400">Waiting for opponent…</h2>
        <p className="text-slate-400 text-sm">Share this game ID:</p>
        <div className="bg-slate-800 border border-slate-600 rounded-lg px-6 py-3 font-mono text-yellow-300 text-sm select-all">
          {game.id}
        </div>
      </div>
    );
  }

  if (game.status === "finished") {
    const iWon = game.winner_slot === game.my_slot;
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-4">
        <h2 className={`text-4xl font-black ${iWon ? "text-yellow-400" : "text-slate-400"}`}>
          {iWon ? "You win!" : "Opponent wins!"}
        </h2>
        <button onClick={() => navigate("/")} className="text-slate-400 underline text-sm">Play again</button>
      </div>
    );
  }

  const mySlot    = game.my_slot!;
  const isMyTurn  = game.current_turn === mySlot;
  const myPeg     = mySlot === "player1" ? game.player1_peg : game.player2_peg;
  const oppPeg    = mySlot === "player1" ? game.player2_peg : game.player1_peg;
  const myCribDiscards    = game.crib_size[mySlot];
  const oppCribDiscards   = mySlot === "player1" ? game.crib_size.player2 : game.crib_size.player1;
  const myDeckSize        = game.deck_size[mySlot];

  function handleCellClick(row: number, col: number) {
    action.mutate(() => api.placeCard(game.id, row, col));
  }

  function handleDiscard() {
    action.mutate(() => api.discardToCrib(game.id));
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col p-3 gap-3">
      {/* Peg track */}
      <PegBoard
        myPeg={myPeg}
        opponentPeg={oppPeg}
        mySlot={mySlot}
        winner={game.winner_slot}
      />

      {/* Round / turn info */}
      <div className="flex items-center justify-between text-xs text-slate-500">
        <span>Round {game.round}</span>
        <span className={isMyTurn ? "text-green-400 font-semibold" : ""}>
          {isMyTurn ? "Your turn" : "Opponent's turn"}
        </span>
        <span>Crib: {game.crib_owner === mySlot ? "Yours" : "Opponent's"}</span>
      </div>

      {/* Main area: board + right panel */}
      <div className="flex gap-4 items-start">
        <Board
          board={game.board}
          mySlot={mySlot}
          starter={game.starter_card}
          rowScores={game.row_scores}
          colScores={game.col_scores}
          isMyTurn={isMyTurn && game.status === "active"}
          onCellClick={handleCellClick}
        />

        <div className="flex flex-col gap-4 min-w-[100px]">
          <CardPreview
            card={game.my_next_card}
            deckSize={myDeckSize}
            isMyTurn={isMyTurn && game.status === "active"}
            onDiscard={handleDiscard}
            canDiscard={myCribDiscards < 2}
            isLoading={action.isPending}
          />

          <CribArea
            myCribCount={myCribDiscards}
            opponentCribCount={oppCribDiscards}
            isMyCrib={game.crib_owner === mySlot}
            cribScore={game.crib_score}
          />
        </div>
      </div>

      {action.error && (
        <p className="text-red-400 text-xs">{action.error.message}</p>
      )}

      {/* Scoring overlay — self-renders null when status !== "scoring" */}
      <ScoringOverlay game={game} mySlot={mySlot} />
    </div>
  );
}
