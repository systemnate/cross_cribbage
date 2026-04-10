# frozen_string_literal: true

class DestroyGameJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game
    return if %w[active scoring].include?(game.status)

    game.destroy!
  end
end
