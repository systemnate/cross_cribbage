# frozen_string_literal: true

class ComputerPlayer
  # AI always plays as player2.
  # player2 scores rows; player1 (opponent) scores columns.
  def initialize(game)
    @game = game
  end

  # Returns { action: :place, row: Integer, col: Integer }
  #      or { action: :discard }
  def decide
    next_card = @game.player2_deck.first
    return { action: :discard } unless next_card

    best_move       = nil
    best_net_impact = nil

    5.times do |row|
      5.times do |col|
        next if @game.board[row][col]  # occupied

        net_impact = simulate_net_impact(row, col, next_card)

        if best_net_impact.nil? || net_impact > best_net_impact
          best_net_impact = net_impact
          best_move = { action: :place, row: row, col: col }
        end
      end
    end

    # Prefer discarding over a net-neutral/negative move if crib still has room
    # and player2 owns the crib (discarding benefits the AI).
    if best_net_impact && best_net_impact <= 0 &&
       @game.player2_crib_discards < 2 && @game.crib_owner == "player2"
      return { action: :discard }
    end

    best_move || { action: :discard }
  end

  private

  def simulate_net_impact(row, col, card)
    current_row_score = @game.row_scores[row].to_i
    current_col_score = @game.col_scores[col].to_i

    row_cards = @game.board[row].each_with_index.map { |c, i| i == col ? card : c }.compact
    col_cards = @game.board.each_with_index.map { |r, i| i == row ? card : r[col] }.compact

    new_row_score = CribbageHand.new(row_cards, starter: @game.starter_card, is_center: row == 2).score
    new_col_score = CribbageHand.new(col_cards, starter: @game.starter_card, is_center: col == 2).score

    (new_row_score - current_row_score) - (new_col_score - current_col_score)
  end
end
