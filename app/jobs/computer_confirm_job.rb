# frozen_string_literal: true

class ComputerConfirmJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.status == "scoring"
    return if game.player2_confirmed_scoring

    game.with_lock do
      next unless game.status == "scoring"
      next if game.player2_confirmed_scoring

      game.confirm_scoring!("player2")
      game.advance_round! if game.both_scoring_confirmed?
    end
    GameChannel.broadcast_game_state(game)
  rescue Game::Error
    # Ignore — game state changed between enqueue and execution.
  end
end
