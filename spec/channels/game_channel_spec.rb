# spec/channels/game_channel_spec.rb
require "rails_helper"

RSpec.describe GameChannel, type: :channel do
  let(:game)  { create(:game, player2_token: SecureRandom.hex(16)) }
  let(:token) { game.player1_token }

  describe "#subscribed" do
    it "subscribes player1 to their own stream" do
      stub_connection player_token: token
      subscribe game_id: game.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("game_#{game.id}_player1")
    end

    it "subscribes player2 to their own stream" do
      stub_connection player_token: game.player2_token
      subscribe game_id: game.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("game_#{game.id}_player2")
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
    it "broadcasts to each player's own stream" do
      game.deal!
      expect {
        GameChannel.broadcast_game_state(game)
      }.to have_broadcasted_to("game_#{game.id}_player1")
        .and have_broadcasted_to("game_#{game.id}_player2")
    end

    it "the payload includes required fields and excludes private HTTP-only fields" do
      game.deal!
      expect {
        GameChannel.broadcast_game_state(game)
      }.to have_broadcasted_to("game_#{game.id}_player1").with(
        hash_including(
          "type" => "game_state",
          "status" => game.status,
          "current_turn" => game.current_turn,
          "crib_size" => hash_including("player1", "player2"),
          "deck_size" => hash_including("player1", "player2")
        )
      ).and(
        have_broadcasted_to("game_#{game.id}_player1").with(
          ->(payload) {
            !payload.key?("my_slot") && !payload.key?("id")
          }
        )
      )
    end

    it "includes player confirmation flags in the broadcast" do
      game.deal!
      expect {
        GameChannel.broadcast_game_state(game)
      }.to have_broadcasted_to("game_#{game.id}_player1").with(
        hash_including(
          "player1_confirmed_scoring" => false,
          "player2_confirmed_scoring" => false
        )
      )
    end

    it "sends each player only their own next card, never the opponent's" do
      game.deal!
      expect {
        GameChannel.broadcast_game_state(game)
      }.to have_broadcasted_to("game_#{game.id}_player1").with(
        hash_including("my_next_card" => game.player1_deck.first.as_json)
      ).and(
        have_broadcasted_to("game_#{game.id}_player2").with(
          hash_including("my_next_card" => game.player2_deck.first.as_json)
        )
      )
    end
  end
end
