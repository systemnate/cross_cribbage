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
    # Mirror game.rb's forced-discard rule: if deck is too small to place, must discard first.
    remaining_crib = 2 - @game.player2_crib_discards
    return { action: :discard } if @game.player2_deck.size <= remaining_crib

    next_card = @game.player2_deck.first
    return { action: :discard } unless next_card

    best_move       = nil
    best_net_impact = nil
    best_potential  = nil

    # Precompute each row's and column's current cards once so simulate_net_impact
    # doesn't rebuild them from scratch for every candidate cell.
    row_base = Array.new(5) { |r| @game.board[r].compact }
    col_base = Array.new(5) { |c| @game.board.map { |r| r[c] }.compact }

    5.times do |row|
      5.times do |col|
        next if @game.board[row][col]  # occupied

        net_impact = simulate_net_impact(row, col, next_card, row_base, col_base)
        potential  = early_game_potential(row, col, next_card)

        if best_net_impact.nil? ||
           net_impact > best_net_impact ||
           (net_impact == best_net_impact && potential > best_potential)
          best_net_impact = net_impact
          best_potential  = potential
          best_move = { action: :place, row: row, col: col }
        end
      end
    end

    # Prefer discarding over a net-neutral/negative move if crib still has room
    # and player2 owns the crib (discarding benefits the AI).
    # Wait until the opponent has placed at least 6 cards so board simulation
    # is meaningful — early on every move looks neutral and premature discards
    # are not a real strategy.
    opponent_cards_placed = 14 - @game.player1_crib_discards - @game.player1_deck.size
    if best_net_impact && best_net_impact <= 0 &&
       @game.player2_crib_discards < 2 && @game.crib_owner == "player2" &&
       opponent_cards_placed >= 6
      return { action: :discard }
    end

    best_move || { action: :discard }
  end

  private

  # Score the early-game potential of placing card at (row, col).
  # Rewards placements that set up runs or fifteens with existing neighbors.
  def early_game_potential(row, col, card)
    potential  = 0
    card_rank  = CribbageHand::RANK_ORDER[card["rank"]]
    card_val   = card_fifteen_value(card)

    existing = @game.board[row].compact + @game.board.map { |r| r[col] }.compact

    existing.each do |other|
      other_rank = CribbageHand::RANK_ORDER[other["rank"]]
      other_val  = card_fifteen_value(other)

      potential += 1 if (card_rank - other_rank).abs == 1  # run-of-2 seed
      potential += 1 if card_val + other_val == 5          # sum-to-5 (fifteen setup with any 10-value card)
    end

    potential
  end

  def card_fifteen_value(card)
    rank = card["rank"]
    return 10 if %w[10 J Q K].include?(rank)
    return 1  if rank == "A"
    rank.to_i
  end

  # Given cards already in a line and a deck to draw from, find the max
  # score achievable by filling `empty_count` slots with cards from `deck`.
  # Pass row_index for rows, col_index for columns (determines is_center).
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

  def simulate_net_impact(row, col, card, row_base = nil, col_base = nil)
    current_row_score = @game.row_scores[row].to_i
    current_col_score = @game.col_scores[col].to_i

    if row_base && col_base
      row_cards = row_base[row] + [card]
      col_cards = col_base[col] + [card]
    else
      row_cards = @game.board[row].each_with_index.map { |c, i| i == col ? card : c }.compact
      col_cards = @game.board.each_with_index.map { |r, i| i == row ? card : r[col] }.compact
    end

    new_row_score = CribbageHand.new(row_cards, starter: @game.starter_card, is_center: row == 2).score
    new_col_score = CribbageHand.new(col_cards, starter: @game.starter_card, is_center: col == 2).score

    (new_row_score - current_row_score) - (new_col_score - current_col_score)
  end
end
