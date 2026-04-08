# app/models/game.rb
# frozen_string_literal: true

class Game < ApplicationRecord
  class Error < StandardError; end

  RANKS = %w[A 2 3 4 5 6 7 8 9 10 J Q K].freeze
  SUITS = %w[♠ ♥ ♦ ♣].freeze
  VALID_SLOTS = %w[player1 player2].freeze

  # ── Class helpers ─────────────────────────────────────────────────────
  def self.generate_token
    SecureRandom.hex(16)
  end

  # ── Player identity ───────────────────────────────────────────────────
  def player_slot(token)
    return "player1" if player1_token == token
    return "player2" if player2_token == token
    nil
  end

  # ── Game start ────────────────────────────────────────────────────────
  # Called when player 2 joins. Randomly assigns crib, sets up round 1.
  def deal!
    self.crib_owner   = %w[player1 player2].sample
    self.current_turn = opposite(crib_owner)
    setup_round!
    self.status = "active"
    save!
  end

  # ── Serialization ─────────────────────────────────────────────────────
  def serialize_for(token)
    slot = player_slot(token)
    {
      id:            id,
      status:        status,
      current_turn:  current_turn,
      round:         round,
      crib_owner:    crib_owner,
      board:         board,
      starter_card:  starter_card,
      row_scores:    row_scores,
      col_scores:    col_scores,
      crib_score:    crib_score,
      crib_size:     { player1: player1_crib_discards, player2: player2_crib_discards },
      deck_size:     { player1: player1_deck.size,     player2: player2_deck.size },
      player1_peg:   player1_peg,
      player2_peg:   player2_peg,
      winner_slot:   winner_slot,
      player1_confirmed_scoring: player1_confirmed_scoring,
      player2_confirmed_scoring: player2_confirmed_scoring,
      my_slot:       slot,
      my_next_card:  slot ? send("#{slot}_deck").first : nil
    }
  end

  # ── Turn actions ──────────────────────────────────────────────────────

  def place_card!(slot, row, col)
    assert_active_turn!(slot)
    raise Error, "Invalid position" unless row.between?(0, 4) && col.between?(0, 4)

    current_board = board.map(&:dup)
    raise Error, "Cell is occupied" if current_board[row][col]

    card = pop_top_card!(slot)
    current_board[row][col] = card
    self.board = current_board

    rescore_row!(row)
    rescore_col!(col)

    board_full? ? enter_scoring_phase! : flip_turn!

    save!
  end

  def discard_to_crib!(slot)
    assert_active_turn!(slot)
    raise Error, "Already discarded 2 cards to the crib" if send("#{slot}_crib_discards") >= 2

    card = pop_top_card!(slot)
    self.crib = crib + [card]
    self.send("#{slot}_crib_discards=", send("#{slot}_crib_discards") + 1)

    # Discards never fill the board (only place_card! does), so always flip turn.
    flip_turn!

    save!
  end

  def confirm_scoring!(slot)
    raise Error, "Invalid slot" unless VALID_SLOTS.include?(slot)
    raise Error, "Game is not in scoring phase" unless status == "scoring"
    send("#{slot}_confirmed_scoring=", true)
    save!
  end

  def both_scoring_confirmed?
    player1_confirmed_scoring && player2_confirmed_scoring
  end

  def advance_round!
    self.round         += 1
    new_crib_owner      = opposite(crib_owner)
    self.crib_owner     = new_crib_owner
    self.current_turn   = opposite(new_crib_owner)   # non-crib player goes first
    setup_round!
    self.status = "active"
    save!
  end

  private

  # ── Round setup ───────────────────────────────────────────────────────
  def setup_round!
    deck    = build_deck
    starter = deck.shift

    self.starter_card = starter

    new_board = Array.new(5) { Array.new(5, nil) }
    new_board[2][2] = starter
    self.board = new_board

    self.player1_deck          = deck.shift(14)
    self.player2_deck          = deck.shift(14)
    self.crib                  = []
    self.player1_crib_discards = 0
    self.player2_crib_discards = 0
    self.row_scores            = [nil, nil, nil, nil, nil]
    self.col_scores            = [nil, nil, nil, nil, nil]
    self.crib_score            = nil
    self.player1_confirmed_scoring = false
    self.player2_confirmed_scoring = false

    # Nibs: starter is a Jack → crib owner scores 2 pts
    if starter["rank"] == "J"
      self.send("#{crib_owner}_peg=", send("#{crib_owner}_peg") + 2)
    end

    rescore_row!(2)
    rescore_col!(2)
  end

  def build_deck
    RANKS.flat_map do |rank|
      SUITS.map { |suit| { "rank" => rank, "suit" => suit, "id" => SecureRandom.uuid } }
    end.shuffle
  end

  # ── Scoring helpers ───────────────────────────────────────────────────
  def rescore_row!(row)
    cards        = board[row].compact
    hand         = CribbageHand.new(cards, starter: starter_card, is_center: row == 2)
    new_scores   = row_scores.dup
    new_scores[row] = hand.score.positive? ? hand.score : nil
    self.row_scores = new_scores
  end

  def rescore_col!(col)
    cards        = board.map { |row| row[col] }.compact
    hand         = CribbageHand.new(cards, starter: starter_card, is_center: col == 2)
    new_scores   = col_scores.dup
    new_scores[col] = hand.score.positive? ? hand.score : nil
    self.col_scores = new_scores
  end

  # ── Turn helpers ──────────────────────────────────────────────────────
  def flip_turn!
    self.current_turn = opposite(current_turn)
  end

  def opposite(slot)
    slot == "player1" ? "player2" : "player1"
  end

  def pop_top_card!(slot)
    deck = send("#{slot}_deck").dup
    card = deck.shift
    raise Error, "No cards left in deck" unless card
    send("#{slot}_deck=", deck)
    card
  end

  def board_full?
    board.flatten.compact.size == 25
  end

  def assert_active_turn!(slot)
    raise Error, "Game is not active" unless status == "active"
    raise Error, "Not your turn"      unless current_turn == slot
  end

  def enter_scoring_phase!
    5.times { |i| rescore_row!(i); rescore_col!(i) }

    self.crib_score = CribbageHand.new(crib, starter: starter_card, is_crib: true).score

    # Game rule (fixed for all rounds): player1 always scores columns; player2 always scores rows.
    # Crib score goes to whichever player owns the crib this round.
    p1_total = col_scores.compact.sum + (crib_owner == "player1" ? crib_score.to_i : 0)
    p2_total = row_scores.compact.sum + (crib_owner == "player2" ? crib_score.to_i : 0)

    diff = (p1_total - p2_total).abs
    if p1_total > p2_total
      self.player1_peg += diff
    elsif p2_total > p1_total
      self.player2_peg += diff
    end

    self.status = if player1_peg >= 31
      self.winner_slot = "player1"
      "finished"
    elsif player2_peg >= 31
      self.winner_slot = "player2"
      "finished"
    else
      "scoring"
    end
  end
end
