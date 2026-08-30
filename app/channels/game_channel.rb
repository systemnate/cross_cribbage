# frozen_string_literal: true

class GameChannel < ApplicationCable::Channel
  def subscribed
    game = Game.find_by(id: params[:game_id])
    return reject unless game

    slot = slot_for(game)
    return reject unless slot

    # Each player streams from their own channel so hidden info (e.g. the
    # other player's next card) is never broadcast to a subscriber who
    # shouldn't see it.
    stream_from "game_#{params[:game_id]}_#{slot}"
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_game_state(game)
    base = {
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
      winner_slot:  game.winner_slot,
      player1_confirmed_scoring: game.player1_confirmed_scoring,
      player2_confirmed_scoring: game.player2_confirmed_scoring,
      crib_hand: game.status == "scoring" ? game.crib : nil
    }

    # Broadcast to each player's own stream with only their own next card
    # attached — never the opponent's (or the computer's) hidden card.
    ActionCable.server.broadcast("game_#{game.id}_player1", base.merge(my_next_card: game.player1_deck.first))
    ActionCable.server.broadcast("game_#{game.id}_player2", base.merge(my_next_card: game.player2_deck.first))
  end

  private

  def slot_for(game)
    return "player1" if game.player1_token == player_token
    return "player2" if game.player2_token == player_token

    nil
  end
end
