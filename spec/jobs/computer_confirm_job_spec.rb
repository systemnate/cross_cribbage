require "rails_helper"

RSpec.describe ComputerConfirmJob, type: :job do
  let(:game_channel_double) { double("GameChannel", broadcast_game_state: nil) }

  before { stub_const("GameChannel", game_channel_double) }

  let(:game) do
    create(:game,
      status:                    "scoring",
      vs_computer:               true,
      player1_token:             Game.generate_token,
      player2_token:             Game.generate_token,
      crib_owner:                "player1",
      current_turn:              nil,
      board:                     Array.new(5) { Array.new(5, nil) },
      row_scores:                [nil, nil, nil, nil, nil],
      col_scores:                [nil, nil, nil, nil, nil],
      starter_card:              { "rank" => "A", "suit" => "♣", "id" => SecureRandom.uuid },
      player1_confirmed_scoring: false,
      player2_confirmed_scoring: false,
      player1_deck:              [],
      player2_deck:              [],
      crib:                      []
    )
  end

  describe "#perform" do
    it "confirms scoring for player2 and broadcasts" do
      expect(game_channel_double).to receive(:broadcast_game_state)
      described_class.new.perform(game.id)

      game.reload
      expect(game.player2_confirmed_scoring).to be(true)
    end

    it "advances the round when both players have confirmed" do
      game.update!(player1_confirmed_scoring: true)
      expect(game_channel_double).to receive(:broadcast_game_state)

      described_class.new.perform(game.id)

      game.reload
      expect(game.status).to eq("active")
      expect(game.round).to eq(2)
    end

    it "does nothing if game is not in scoring phase" do
      game.update!(status: "active")
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if player2 already confirmed" do
      game.update!(player2_confirmed_scoring: true)
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if game does not exist" do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
    end
  end
end
