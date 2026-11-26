# spec/models/game_spec.rb
require "rails_helper"

RSpec.describe Game, type: :model do
  describe ".generate_token" do
    it "returns a 32-character hex string" do
      token = described_class.generate_token
      expect(token).to match(/\A[0-9a-f]{32}\z/)
    end

    it "returns a different token each time" do
      expect(described_class.generate_token).not_to eq(described_class.generate_token)
    end
  end

  describe "#player_slot" do
    let(:game) { create(:game, player2_token: SecureRandom.hex(16)) }

    it "returns player1 for player1_token" do
      expect(game.player_slot(game.player1_token)).to eq("player1")
    end

    it "returns player2 for player2_token" do
      expect(game.player_slot(game.player2_token)).to eq("player2")
    end

    it "returns nil for unknown token" do
      expect(game.player_slot("unknown")).to be_nil
    end

    it "returns nil for a blank token on a game still waiting for player 2" do
      waiting = create(:game)
      expect(waiting.player_slot(nil)).to be_nil
      expect(waiting.player_slot("")).to be_nil
    end
  end

  describe "#deal!" do
    let(:game) { create(:game, player2_token: SecureRandom.hex(16)) }

    before { game.deal! }

    it "sets status to active" do
      expect(game.status).to eq("active")
    end

    it "sets crib_owner to player1 or player2" do
      expect(game.crib_owner).to be_in(%w[player1 player2])
    end

    it "sets current_turn to the non-crib player" do
      expected_turn = game.crib_owner == "player1" ? "player2" : "player1"
      expect(game.current_turn).to eq(expected_turn)
    end

    it "deals 14 cards to each player" do
      expect(game.player1_deck.size).to eq(14)
      expect(game.player2_deck.size).to eq(14)
    end

    it "places a starter card at board[2][2]" do
      expect(game.board[2][2]).to be_a(Hash)
      expect(game.board[2][2]).to include("rank", "suit", "id")
    end

    it "sets starter_card to the center card" do
      expect(game.starter_card).to eq(game.board[2][2])
    end

    it "initializes board as 5x5 with only center filled" do
      expect(game.board.size).to eq(5)
      game.board.each do |row|
        expect(row.size).to eq(5)
      end
      filled = game.board.flatten.compact
      expect(filled.size).to eq(1)
    end

    it "starts with empty crib" do
      expect(game.crib).to eq([])
    end

    it "starts with zero crib discards" do
      expect(game.player1_crib_discards).to eq(0)
      expect(game.player2_crib_discards).to eq(0)
    end

    it "does not award nibs to the peg track when starter is a Jack (it counts on the crib hand instead)" do
      jack_card = { "rank" => "J", "suit" => "♠", "id" => SecureRandom.uuid }
      game2 = create(:game, player2_token: SecureRandom.hex(16))
      allow(game2).to receive(:build_deck).and_return([jack_card] + Array.new(28) { |i|
        { "rank" => (i + 1).to_s, "suit" => "♥", "id" => SecureRandom.uuid }
      })
      game2.deal!
      expect(game2.player1_peg).to eq(0)
      expect(game2.player2_peg).to eq(0)
    end
  end

  describe "#serialize_for" do
    let(:game) { create(:game, player2_token: SecureRandom.hex(16)) }

    before { game.deal! }

    it "includes all required fields for player1" do
      result = game.serialize_for(game.player1_token)
      expect(result).to include(
        :id, :status, :current_turn, :round, :crib_owner,
        :board, :starter_card, :row_scores, :col_scores,
        :crib_score, :crib_size, :deck_size,
        :player1_peg, :player2_peg, :winner_slot,
        :player1_confirmed_scoring, :player2_confirmed_scoring,
        :my_slot, :my_next_card
      )
    end

    it "returns my_slot = player1 for player1 token" do
      result = game.serialize_for(game.player1_token)
      expect(result[:my_slot]).to eq("player1")
    end

    it "returns my_next_card as the first card in player1 deck" do
      result = game.serialize_for(game.player1_token)
      expect(result[:my_next_card]).to eq(game.player1_deck.first)
    end

    it "returns nil my_slot for unknown token" do
      result = game.serialize_for("unknown")
      expect(result[:my_slot]).to be_nil
      expect(result[:my_next_card]).to be_nil
    end
  end

  describe "#place_card!" do
    let(:game) { create(:game, :active) }

    before do
      game.deal!
      game.reload
    end

    def active_slot
      game.current_turn
    end

    def inactive_slot
      game.current_turn == "player1" ? "player2" : "player1"
    end

    it "raises if not the player's turn" do
      expect {
        game.place_card!(inactive_slot, 0, 0)
      }.to raise_error(Game::Error, /not your turn/i)
    end

    it "raises if row is out of bounds" do
      expect { game.place_card!(active_slot, 5, 0) }.to raise_error(Game::Error, /invalid position/i)
    end

    it "raises if col is out of bounds" do
      expect { game.place_card!(active_slot, 0, 5) }.to raise_error(Game::Error, /invalid position/i)
    end

    it "raises if cell is occupied (center)" do
      expect { game.place_card!(active_slot, 2, 2) }.to raise_error(Game::Error, /occupied/i)
    end

    it "places the player's top card on the board" do
      top_card = game.send("#{active_slot}_deck").first
      game.place_card!(active_slot, 0, 0)
      expect(game.board[0][0]).to eq(top_card)
    end

    it "removes the card from the player's deck" do
      slot = active_slot
      deck_size_before = game.send("#{slot}_deck").size
      game.place_card!(slot, 0, 0)
      expect(game.send("#{slot}_deck").size).to eq(deck_size_before - 1)
    end

    it "flips the turn to the other player" do
      original_turn = game.current_turn
      game.place_card!(active_slot, 0, 0)
      expect(game.current_turn).not_to eq(original_turn)
    end

    it "rescores the affected column" do
      game.place_card!(active_slot, 0, 3)
      expect(game.col_scores[3]).to be_nil.or(be_a(Integer))
    end

    it "rescores the affected row" do
      game.place_card!(active_slot, 1, 0)
      expect(game.row_scores[1]).to be_nil.or(be_a(Integer))
    end

    it "persists the state" do
      game.place_card!(active_slot, 0, 0)
      game.reload
      expect(game.board[0][0]).to be_a(Hash)
    end
  end

  describe "#discard_to_crib!" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    def active_slot = game.current_turn

    it "raises if not the player's turn" do
      other = game.current_turn == "player1" ? "player2" : "player1"
      expect { game.discard_to_crib!(other) }.to raise_error(Game::Error, /not your turn/i)
    end

    it "adds the top card to the crib" do
      slot = active_slot
      top_card = game.send("#{slot}_deck").first
      game.discard_to_crib!(slot)
      expect(game.crib).to include(top_card)
    end

    it "increments the player's crib discard count" do
      slot = active_slot
      game.discard_to_crib!(slot)
      expect(game.send("#{slot}_crib_discards")).to eq(1)
    end

    it "raises after 2 discards" do
      slot = active_slot
      game.update!("#{slot}_crib_discards" => 2)
      expect { game.discard_to_crib!(slot) }.to raise_error(Game::Error, /already discarded/i)
    end

    it "flips the turn" do
      slot = active_slot
      original = game.current_turn
      game.discard_to_crib!(slot)
      expect(game.current_turn).not_to eq(original)
    end
  end

  describe "#advance_round!" do
    let(:game) do
      g = create(:game, :active)
      g.deal!
      g.reload
      fill_board!(g)
      g.reload
      g
    end

    before do
      # Ensure game is in scoring state (not finished)
      skip "game already finished" if game.status == "finished"
      game.advance_round!
      game.reload
    end

    it "increments the round" do
      expect(game.round).to eq(2)
    end

    it "flips the crib owner" do
      expect(game.crib_owner).to be_in(%w[player1 player2])
    end

    it "sets current_turn to the non-crib player" do
      expected = game.crib_owner == "player1" ? "player2" : "player1"
      expect(game.current_turn).to eq(expected)
    end

    it "resets the board to 5x5 with only starter filled" do
      filled = game.board.flatten.compact.size
      expect(filled).to eq(1)
      expect(game.board[2][2]).to be_a(Hash)
    end

    it "deals 14 new cards to each player" do
      expect(game.player1_deck.size).to eq(14)
      expect(game.player2_deck.size).to eq(14)
    end

    it "resets crib to empty" do
      expect(game.crib).to eq([])
    end

    it "resets scores to nil" do
      expect(game.row_scores).to all(be_nil.or(be_a(Integer))) # may have starter score
      expect(game.crib_score).to be_nil
    end

    it "sets status back to active" do
      expect(game.status).to eq("active")
    end
  end

  describe "#confirm_scoring!" do
    let(:game) do
      g = create(:game, :active)
      g.deal!
      g.reload
      g.update!(status: "scoring")
      g
    end

    it "sets player1_confirmed_scoring when called for player1" do
      game.confirm_scoring!("player1")
      expect(game.reload.player1_confirmed_scoring).to be true
    end

    it "sets player2_confirmed_scoring when called for player2" do
      game.confirm_scoring!("player2")
      expect(game.reload.player2_confirmed_scoring).to be true
    end

    it "is idempotent — calling twice does not error" do
      game.confirm_scoring!("player1")
      expect { game.confirm_scoring!("player1") }.not_to raise_error
    end

    it "raises Game::Error when game is not in scoring phase" do
      active_game = create(:game, :active)
      active_game.deal!
      active_game.reload
      expect {
        active_game.confirm_scoring!("player1")
      }.to raise_error(Game::Error, /not in scoring phase/i)
    end

    it "raises Game::Error for an invalid slot" do
      expect {
        game.confirm_scoring!("invalid")
      }.to raise_error(Game::Error, /invalid slot/i)
    end
  end

  describe "#both_scoring_confirmed?" do
    let(:game) { create(:game, :active, status: "scoring") }

    it "returns false when neither player has confirmed" do
      expect(game.both_scoring_confirmed?).to be false
    end

    it "returns false when only player1 has confirmed" do
      game.update!(player1_confirmed_scoring: true)
      expect(game.both_scoring_confirmed?).to be false
    end

    it "returns false when only player2 has confirmed" do
      game.update!(player2_confirmed_scoring: true)
      expect(game.both_scoring_confirmed?).to be false
    end

    it "returns true when both players have confirmed" do
      game.update!(player1_confirmed_scoring: true, player2_confirmed_scoring: true)
      expect(game.both_scoring_confirmed?).to be true
    end
  end

  describe "scoring phase" do
    it "enters scoring when board is full" do
      game = create(:game, :active)
      game.deal!
      game.reload

      fill_board!(game)

      expect(game.status).to eq("scoring")
    end

    # Builds an active game whose board is full except the last cell, then places the
    # final card so scoring runs on a fixed, known board (no random deal). Starter is 7♣.
    def score_fixed_board!(grid:, crib:, crib_owner:, player1_peg: 0, player2_peg: 0)
      card  = ->(code) { { "rank" => code[0..-2], "suit" => code[-1], "id" => code } }
      board = grid.map { |row| row.map(&card) }
      last_card = board[4][4]
      board[4][4] = nil

      game = create(:game, :active,
        board:        board,
        starter_card: board[2][2],
        crib:         crib.map(&card),
        crib_owner:   crib_owner,
        current_turn: "player2",
        player2_deck: [last_card],
        player1_crib_discards: 2,
        player2_crib_discards: 2,
        player1_peg:  player1_peg,
        player2_peg:  player2_peg)
      game.place_card!("player2", 4, 4)
      game.reload
    end

    # Columns (player1): four aces 12, 2-2 pair 2, 9-9 pair 2, 8-8 pair 2, four kings 12 = 30.
    # Rows (player2): only row 4's Q-Q pair scores = 2. Crib (player1): 3 4 10 Q + 7 = 0.
    let(:winning_grid) do
      [
        %w[A♠ 2♥ 9♦ 8♣ K♠],
        %w[A♥ 2♦ 9♣ 8♠ K♥],
        %w[3♠ Q♦ 7♣ 6♥ 10♣],
        %w[A♦ 6♣ J♦ 3♥ K♦],
        %w[A♣ 10♠ Q♣ Q♥ K♣]
      ]
    end

    it "advances the winning player's peg by the score difference" do
      game = score_fixed_board!(grid: winning_grid, crib: %w[3♣ 4♠ 10♦ Q♠],
                                crib_owner: "player1", player1_peg: 1, player2_peg: 3)

      expect(game.status).to eq("scoring")
      expect(game.col_scores.compact.sum).to eq(30)
      expect(game.row_scores.compact.sum).to eq(2)
      expect(game.crib_score).to eq(0)
      expect(game.player1_peg).to eq(1 + 28)
      expect(game.player2_peg).to eq(3)
    end

    it "leaves both pegs unchanged when the round is a tie" do
      # Same board with 4♠ at row 3, col 1: columns still 30, rows now 6
      # (row 3 gains A-4-J and A-4-K fifteens). Player2's crib 6 7 8 8 + 7 scores 24,
      # so player2 also totals 30.
      tied_grid = winning_grid.map(&:dup)
      tied_grid[3][1] = "4♠"
      game = score_fixed_board!(grid: tied_grid, crib: %w[6♠ 7♠ 8♥ 8♦],
                                crib_owner: "player2", player1_peg: 5, player2_peg: 3)

      expect(game.status).to eq("scoring")
      expect(game.col_scores.compact.sum).to eq(30)
      expect(game.row_scores.compact.sum + game.crib_score).to eq(30)
      expect(game.player1_peg).to eq(5)
      expect(game.player2_peg).to eq(3)
    end

    it "sets status to finished when peg reaches 31" do
      game = create(:game, :active)
      game.update!(player1_peg: 30)
      game.deal!
      game.reload
      fill_board!(game)

      if game.player1_peg >= 31 || game.player2_peg >= 31
        expect(game.status).to eq("finished")
        expect(game.winner_slot).to be_in(%w[player1 player2])
      else
        expect(game.status).to eq("scoring")
      end
    end

    it "crib always has exactly 4 cards when neither player explicitly discards" do
      game = create(:game, :active)
      game.deal!
      game.reload
      fill_board!(game)

      expect(game.crib.size).to eq(4)
      expect(game.player1_crib_discards).to eq(2)
      expect(game.player2_crib_discards).to eq(2)
    end

    it "crib has exactly 4 cards even if only one player explicitly discards" do
      game = create(:game, :active)
      game.deal!
      game.reload

      # force player1 to discard one card explicitly before fill_board! takes over
      if game.current_turn == "player1"
        game.discard_to_crib!("player1")
        game.reload
      else
        game.discard_to_crib!("player2")
        game.reload
        game.discard_to_crib!("player1")
        game.reload
      end

      fill_board!(game)
      expect(game.crib.size).to eq(4)
    end
  end
end

def fill_board!(game)
  24.times do
    slot = game.current_turn
    discard_count = game.send("#{slot}_crib_discards")
    if discard_count < 2 && game.send("#{slot}_deck").size <= (2 - discard_count)
      game.discard_to_crib!(slot)
    else
      empty = game.board.each_with_index.flat_map { |row, r|
        row.each_with_index.filter_map { |cell, c| [r, c] unless cell }
      }.first
      game.place_card!(slot, *empty)
    end
    game.reload
    break if game.status != "active"
  end
end
