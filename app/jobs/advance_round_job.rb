# frozen_string_literal: true

class AdvanceRoundJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.status == "scoring"

    game.advance_round!
    GameChannel.broadcast_game_state(game)
  end
end
