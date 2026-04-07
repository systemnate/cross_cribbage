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
      allow(game).to receive(:build_deck).and_return([jack_card] + Array.new(28) { |i|
        { "rank" => i.to_s, "suit" => "♥", "id" => SecureRandom.uuid }
      })
      game2 = create(:game, player2_token: SecureRandom.hex(16))
      allow(game2).to receive(:build_deck).and_return([jack_card] + Array.new(28) { |i|
        { "rank" => (i + 1).to_s, "suit" => "♥", "id" => SecureRandom.uuid }
      })
      game2.deal!
      peg = game2.crib_owner == "player1" ? game2.player1_peg : game2.player2_peg
      expect(peg).to eq(2)
    end
  end
end
