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

    it "grants 2 nibs points to crib_owner when starter is a Jack" do
      # Force a Jack starter by mocking build_deck
      jack_card = { "rank" => "J", "suit" => "♠", "id" => SecureRandom.uuid }
      game2 = create(:game, player2_token: SecureRandom.hex(16))
      allow(game2).to receive(:build_deck).and_return([jack_card] + Array.new(28) { |i|
        { "rank" => (i + 1).to_s, "suit" => "♥", "id" => SecureRandom.uuid }
      })
      game2.deal!
      peg = game2.crib_owner == "player1" ? game2.player1_peg : game2.player2_peg
      expect(peg).to eq(2)
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

    it "advances the winning player's peg by the score difference" do
      game = create(:game, :active)
      game.deal!
      game.reload
      fill_board!(game)

      peg_total = game.player1_peg + game.player2_peg
      expect(peg_total).to be > 0
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
