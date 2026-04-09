# frozen_string_literal: true

class ComputerMoveJob < ApplicationJob
  queue_as :default

  def perform(game_id)
    game = Game.find_by(id: game_id)
    return unless game&.status == "active"
    return unless game.current_turn == "player2"
    return unless game.vs_computer?

    decision = ComputerPlayer.new(game).decide

    case decision[:action]
    when :discard
      game.discard_to_crib!("player2")
    when :place
      game.place_card!("player2", decision[:row], decision[:col])
    end

    GameChannel.broadcast_game_state(game)
  rescue Game::Error
    # Game state changed between enqueue and execution; skip silently.
  end
end
