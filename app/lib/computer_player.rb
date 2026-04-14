# frozen_string_literal: true

class ComputerPlayer
  # AI always plays as player2.
  # player2 scores rows; player1 (opponent) scores columns.

  DEFENSIVE_WEIGHT     = 1.0
  ROW_POTENTIAL_WEIGHT = 0.3

  def initialize(game)
    @game = game
  end

  # Returns { action: :place, row: Integer, col: Integer }
  #      or { action: :discard }
  def decide
    # Mirror game.rb's forced-discard rule: if deck is too small to place, must discard first.
    remaining_crib = 2 - @game.player2_crib_discards
    return { action: :discard } if @game.player2_deck.size <= remaining_crib

    next_card = @game.player2_deck.first
    return { action: :discard } unless next_card

    best_move  = nil
    best_score = nil

    # Precompute each row's and column's current cards once.
    row_base = Array.new(5) { |r| @game.board[r].compact }
    col_base = Array.new(5) { |c| @game.board.map { |r| r[c] }.compact }

    5.times do |row|
      5.times do |col|
        next if @game.board[row][col]  # occupied

        net    = simulate_net_impact(row, col, next_card, row_base, col_base)
        defend = defensive_score(row, col, next_card, col_base)
        potential = row_potential(row, col, next_card, row_base)

        total = net + (defend * DEFENSIVE_WEIGHT) + (potential * ROW_POTENTIAL_WEIGHT)

        if best_score.nil? || total > best_score
          best_score = total
          best_move  = { action: :place, row: row, col: col }
        end
      end
    end

    # Prefer discarding over a net-neutral/negative move if crib still has room
    # and player2 owns the crib (discarding benefits the AI).
    # Wait until the opponent has placed at least 6 cards so board simulation
    # is meaningful.
    opponent_cards_placed = 14 - @game.player1_crib_discards - @game.player1_deck.size
    if best_score && best_score <= 0 &&
       @game.player2_crib_discards < 2 && @game.crib_owner == "player2" &&
       opponent_cards_placed >= 6
      return { action: :discard }
    end

    best_move || { action: :discard }
  end

  private

  def simulate_net_impact(row, col, card, row_base, col_base)
    row_cards = row_base[row] + [card]
    col_cards = col_base[col] + [card]

    current_row_score = CribbageHand.new(row_base[row], starter: @game.starter_card, is_center: row == 2).score
    current_col_score = CribbageHand.new(col_base[col], starter: @game.starter_card, is_center: col == 2).score

    new_row_score = CribbageHand.new(row_cards, starter: @game.starter_card, is_center: row == 2).score
    new_col_score = CribbageHand.new(col_cards, starter: @game.starter_card, is_center: col == 2).score

    (new_row_score - current_row_score) - (new_col_score - current_col_score)
  end

  # Evaluate how placing `card` at (row, col) affects the opponent's
  # best-case score in that column. Positive = disrupted opponent.
  def defensive_score(row, col, card, col_base)
    col_cards_without = col_base[col]
    col_cards_with    = col_cards_without + [card]

    empty_without = 5 - col_cards_without.size
    empty_with    = 5 - col_cards_with.size

    opponent_deck = @game.player1_deck

    potential_without = best_fill_score(col_cards_without, opponent_deck, empty_without, col_index: col)
    potential_with    = best_fill_score(col_cards_with, opponent_deck, empty_with, col_index: col)

    potential_without - potential_with
  end

  # Evaluate the future scoring ceiling of placing `card` in this row.
  # Returns 0 for row-completing placements (net_impact handles those).
  # Returns positive values for rows with high upside.
  def row_potential(row, col, card, row_base)
    row_cards_with = row_base[row] + [card]
    empty_after = 5 - row_cards_with.size

    return 0 if empty_after == 0

    current_row_score = @game.row_scores[row].to_i
    best_case = best_fill_score(row_cards_with, @game.player2_deck, empty_after, row_index: row)

    best_case - current_row_score
  end

  # Given cards already in a line and a deck to draw from, find the max
  # score achievable by filling `empty_count` slots with cards from `deck`.
  def best_fill_score(existing_cards, deck, empty_count, row_index: nil, col_index: nil)
    is_center = (row_index == 2 || col_index == 2)

    if empty_count == 0 || deck.empty?
      return CribbageHand.new(existing_cards, starter: @game.starter_card, is_center: is_center).score
    end

    fillable = [empty_count, deck.size].min
    best = 0

    deck.combination(fillable).each do |combo|
      hand = existing_cards + combo
      score = CribbageHand.new(hand, starter: @game.starter_card, is_center: is_center).score
      best = score if score > best
    end

    best
  end
end
