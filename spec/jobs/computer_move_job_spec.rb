require "rails_helper"

RSpec.describe ComputerMoveJob, type: :job do
  let(:game_channel_double) { double("GameChannel", broadcast_game_state: nil) }

  before { stub_const("GameChannel", game_channel_double) }

  def card(rank, suit)
    { "rank" => rank, "suit" => suit, "id" => SecureRandom.uuid }
  end

  # A minimal active vs-computer game where it's player2's turn.
  # player2 has one card (5♠) and has already discarded 2 (so it must place).
  # The board is empty so any cell is valid.
  let(:game) do
    create(:game,
      status:                "active",
      vs_computer:           true,
      player1_token:         Game.generate_token,
      player2_token:         Game.generate_token,
      current_turn:          "player2",
      crib_owner:            "player1",
      board:                 Array.new(5) { Array.new(5, nil) },
      row_scores:            [nil, nil, nil, nil, nil],
      col_scores:            [nil, nil, nil, nil, nil],
      starter_card:          card("A", "♣"),
      player1_deck:          [card("2", "♥")],
      player2_deck:          [card("5", "♠")],
      player2_crib_discards: 2
    )
  end

  describe "#perform" do
    it "places a card and broadcasts" do
      expect(game_channel_double).to receive(:broadcast_game_state)
      described_class.new.perform(game.id)

      game.reload
      placed = game.board.flatten.compact
      expect(placed.size).to eq(1)
      expect(placed.first["rank"]).to eq("5")
    end

    it "does nothing if game is not active" do
      game.update!(status: "waiting")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if it is not player2's turn" do
      game.update!(current_turn: "player1")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if game does not exist" do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
    end
  end
end
