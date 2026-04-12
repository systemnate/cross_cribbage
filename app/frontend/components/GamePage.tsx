import React, { useState, useCallback, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useGame } from "../hooks/useGame";
import { useGameChannel } from "../hooks/useGameChannel";
import { useGameAction } from "../hooks/useGameAction";
import { api } from "../lib/api";
import { getGameId, removeGame } from "../lib/storage";
import { Board } from "./Board";
import { PegBoard } from "./PegBoard";
import { CardPreview } from "./CardPreview";
import { CribArea } from "./CribArea";
import { ScoringOverlay } from "./ScoringOverlay";
import { CopyLinkButton } from "./CopyLinkButton";

export function GamePage() {
  const { id: urlId } = useParams<{ id: string }>();
  const navigate       = useNavigate();
  const gameId         = urlId ?? getGameId() ?? null;

  const { data: game, isLoading, error } = useGame(gameId);
  const [lastOpponentPlay, setLastOpponentPlay] = useState<{ row: number; col: number } | null>(null);
  const handleOpponentCardPlayed = useCallback((row: number, col: number) => {
    setLastOpponentPlay({ row, col });
    setTimeout(() => setLastOpponentPlay(null), 2000);
  }, []);
  useGameChannel(gameId, handleOpponentCardPlayed);
  const action = useGameAction(gameId);

  useEffect(() => {
    if (gameId && game?.status === "finished") {
      removeGame(gameId);
    }
  }, [gameId, game?.status]);

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
        <p className="text-slate-400 text-sm">Send this link to your opponent:</p>
        <CopyLinkButton gameId={game.id} />
      </div>
    );
  }

  if (game.status === "finished") {
    const iWon = game.winner_slot === game.my_slot;
    const confettiColors = ["bg-yellow-400", "bg-green-400", "bg-blue-400", "bg-purple-400", "bg-red-400", "bg-orange-400", "bg-pink-400"];
    const confettiPieces = Array.from({ length: 70 }, (_, i) => ({
      color: confettiColors[i % confettiColors.length],
      left: `${(i * 37 + 11) % 100}%`,
      delay: `${((i * 0.17) % 2.5).toFixed(2)}s`,
      duration: `${(2.2 + (i * 0.09) % 1.8).toFixed(2)}s`,
      wide: i % 3 !== 0,
    }));

    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 relative overflow-hidden">
        {iWon && (
          <div className="fixed inset-0 pointer-events-none overflow-hidden">
            {confettiPieces.map((p, i) => (
              <div
                key={i}
                className={`absolute top-0 ${p.wide ? "w-2 h-3" : "w-3 h-3 rounded-sm"} ${p.color} confetti-piece`}
                style={{ left: p.left, animationDelay: p.delay, animationDuration: p.duration }}
              />
            ))}
          </div>
        )}
        <h2 className={`text-5xl font-black tracking-tight ${iWon ? "text-yellow-400" : "text-slate-400"}`}>
          {iWon ? "You win!" : "Opponent wins."}
        </h2>
        <button onClick={() => navigate("/")} className="text-slate-400 underline text-sm">Play again</button>
      </div>
    );
  }

  if (!game.my_slot) {
    return <div className="min-h-screen bg-slate-950 text-slate-400 flex items-center justify-center">Joining game…</div>;
  }

  const mySlot    = game.my_slot;
  const oppSlot   = mySlot === "player1" ? "player2" : "player1";
  const isMyTurn  = game.current_turn === mySlot;
  const myPeg     = game[`${mySlot}_peg`];
  const oppPeg    = game[`${oppSlot}_peg`];
  const myCribDiscards  = game.crib_size[mySlot];
  const oppCribDiscards = game.crib_size[oppSlot];
  const myDeckSize      = game.deck_size[mySlot];
  const isInteractable  = isMyTurn && game.status === "active";
  const mustDiscardFirst = isInteractable && myCribDiscards < 2 && myDeckSize <= (2 - myCribDiscards);

  const sum = (scores: (number | null)[]) => scores.reduce<number>((acc, s) => acc + (s ?? 0), 0);
  const myBoardScore  = sum(mySlot === "player1" ? game.col_scores : game.row_scores);
  const oppBoardScore = sum(mySlot === "player1" ? game.row_scores : game.col_scores);

  const { id: gid } = game;

  function handleCellClick(row: number, col: number) {
    action.mutate({
      action: () => api.placeCard(gid, row, col),
      optimistic: (old) => {
        if (!old.my_next_card) return {};
        const board = old.board.map(r => [...r]);
        board[row][col] = old.my_next_card;
        const mySlot = old.my_slot!;
        const oppSlot = mySlot === "player1" ? "player2" : "player1";
        const boardWillFull = old.board.flat().filter(Boolean).length === 24;
        return {
          board,
          my_next_card: null,
          deck_size: { ...old.deck_size, [mySlot]: old.deck_size[mySlot] - 1 },
          ...(boardWillFull ? {} : { current_turn: oppSlot }),
        };
      },
    });
  }

  function handleDiscard() {
    action.mutate({
      action: () => api.discardToCrib(gid),
      optimistic: (old) => {
        if (!old.my_next_card) return {};
        const mySlot = old.my_slot!;
        const oppSlot = mySlot === "player1" ? "player2" : "player1";
        return {
          my_next_card: null,
          deck_size: { ...old.deck_size, [mySlot]: old.deck_size[mySlot] - 1 },
          crib_size: { ...old.crib_size, [mySlot]: old.crib_size[mySlot] + 1 },
          current_turn: oppSlot,
        };
      },
    });
  }

  function handleConfirmRound() {
    action.mutate({ action: () => api.confirmRound(gid) });
  }

  return (
    <div className="h-dvh bg-slate-950 overflow-hidden">
      <div className="h-full w-full max-w-3xl mx-auto text-slate-100 flex flex-col p-2 gap-2 sm:p-3 sm:gap-3">
        {/* Peg track */}
        <PegBoard
          myPeg={myPeg}
          opponentPeg={oppPeg}
          myBoardScore={myBoardScore}
          oppBoardScore={oppBoardScore}
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
        <div className="flex-1 min-h-0 flex flex-col gap-3 md:flex-row md:gap-4 md:items-start">
          <div className="flex-1 min-h-0 md:min-w-0">
            <Board
              board={game.board}
              mySlot={mySlot}
              starter={game.starter_card}
              rowScores={game.row_scores}
              colScores={game.col_scores}
              isMyTurn={isInteractable && !mustDiscardFirst}
              onCellClick={handleCellClick}
              lastOpponentPlay={lastOpponentPlay}
            />
          </div>

          <div className="flex-shrink-0 flex gap-4 md:flex-col md:min-w-[100px]">
            <CardPreview
              card={game.my_next_card}
              deckSize={myDeckSize}
              isMyTurn={isInteractable}
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
        <ScoringOverlay
          game={game}
          mySlot={mySlot}
          onConfirm={handleConfirmRound}
          isConfirmPending={action.isPending}
        />
      </div>
    </div>
  );
}
