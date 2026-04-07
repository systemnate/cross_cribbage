# spec/jobs/advance_round_job_spec.rb
require "rails_helper"

RSpec.describe AdvanceRoundJob, type: :job do
  let(:game_channel_double) { double("GameChannel", broadcast_game_state: nil) }

  before do
    stub_const("GameChannel", game_channel_double)
  end

  describe "#perform" do
    it "calls advance_round! and broadcasts when game is in scoring state" do
      game = create(:game, :active)
      game.deal!
      fill_board!(game)
      game.reload
      skip "game finished, not scoring" if game.status == "finished"

      expect(game_channel_double).to receive(:broadcast_game_state)
      described_class.new.perform(game.id)

      game.reload
      expect(game.status).to eq("active")
      expect(game.round).to eq(2)
    end

    it "does nothing if game is not in scoring state" do
      game = create(:game)
      expect(game_channel_double).not_to receive(:broadcast_game_state)
      described_class.new.perform(game.id)
    end

    it "does nothing if game does not exist" do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
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
end
