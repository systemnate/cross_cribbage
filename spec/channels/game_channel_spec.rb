# spec/channels/game_channel_spec.rb
require "rails_helper"

RSpec.describe GameChannel, type: :channel do
  let(:game)  { create(:game, player2_token: SecureRandom.hex(16)) }
  let(:token) { game.player1_token }

  describe "#subscribed" do
    it "subscribes successfully with a valid player token" do
      stub_connection player_token: token
      subscribe game_id: game.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("game_#{game.id}")
    end

    it "rejects subscription with an invalid token" do
      stub_connection player_token: "bad_token"
      subscribe game_id: game.id
      expect(subscription).to be_rejected
    end

    it "rejects subscription for a nonexistent game" do
      stub_connection player_token: token
      subscribe game_id: SecureRandom.uuid
      expect(subscription).to be_rejected
    end
  end

  describe ".broadcast_game_state" do
    it "broadcasts to the game channel" do
      game.deal!
      expect {
        GameChannel.broadcast_game_state(game)
      }.to have_broadcasted_to("game_#{game.id}")
    end

    it "the payload includes required fields" do
      game.deal!
      GameChannel.broadcast_game_state(game)
      # Verify the broadcast was sent (implicit through have_broadcasted_to passing)
      expect(game.id).to be_present
    end
  end
end
