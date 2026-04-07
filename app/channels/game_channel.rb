# frozen_string_literal: true

class GameChannel < ApplicationCable::Channel
  def subscribed
    game = Game.find_by(id: params[:game_id])
    return reject unless game
    return reject unless game.player1_token == player_token ||
                         game.player2_token == player_token

    stream_from "game_#{params[:game_id]}"
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_game_state(game)
    ActionCable.server.broadcast(
      "game_#{game.id}",
      {
        type:         "game_state",
        status:       game.status,
        current_turn: game.current_turn,
        round:        game.round,
        crib_owner:   game.crib_owner,
        board:        game.board,
        starter_card: game.starter_card,
        row_scores:   game.row_scores,
        col_scores:   game.col_scores,
        crib_score:   game.crib_score,
        crib_size:    { player1: game.player1_crib_discards,
                        player2: game.player2_crib_discards },
        deck_size:    { player1: game.player1_deck.size,
                        player2: game.player2_deck.size },
        player1_peg:  game.player1_peg,
        player2_peg:  game.player2_peg,
        winner_slot:  game.winner_slot
      }
    )
  end
end
