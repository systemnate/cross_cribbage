# spec/requests/games_spec.rb
require "rails_helper"

RSpec.describe "Api::Games", type: :request do
  def json = JSON.parse(response.body)

  describe "POST /api/games" do
    it "creates a game and returns game_id and token" do
      post "/api/games"
      expect(response).to have_http_status(:created)
      expect(json).to include("game_id", "token")
    end
  end

  describe "POST /api/games/:id/join" do
    let(:game) { create(:game) }

    it "returns a token for player 2 and starts the game" do
      post "/api/games/#{game.id}/join"
      expect(response).to have_http_status(:ok)
      expect(json).to include("token")
      expect(game.reload.status).to eq("active")
    end

    it "returns error when game already has two players" do
      g2 = create(:game, player2_token: SecureRandom.hex(16))
      post "/api/games/#{g2.id}/join"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/games/:id" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    it "returns game state for an authenticated player" do
      get "/api/games/#{game.id}",
          headers: { "X-Player-Token" => game.player1_token }
      expect(response).to have_http_status(:ok)
      expect(json).to include("status", "board", "my_slot", "my_next_card")
      expect(json["my_slot"]).to eq("player1")
    end

    it "returns my_next_card for the requesting player" do
      get "/api/games/#{game.id}",
          headers: { "X-Player-Token" => game.player2_token }
      expect(json["my_slot"]).to eq("player2")
      expect(json["my_next_card"]).to be_a(Hash)
    end
  end

  describe "POST /api/games/:id/place_card" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    it "places the card and returns updated state" do
      token = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/place_card",
           params: { row: 0, col: 0 },
           headers: { "X-Player-Token" => token }
      expect(response).to have_http_status(:ok)
      expect(json["board"][0][0]).to be_a(Hash)
    end

    it "returns error for wrong player" do
      other_slot = game.current_turn == "player1" ? "player2" : "player1"
      token = game.send("#{other_slot}_token")
      post "/api/games/#{game.id}/place_card",
           params: { row: 0, col: 0 },
           headers: { "X-Player-Token" => token }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without a token" do
      post "/api/games/#{game.id}/place_card", params: { row: 0, col: 0 }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/games/:id/discard_to_crib" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    it "discards to crib and returns updated state" do
      token = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/discard_to_crib",
           headers: { "X-Player-Token" => token }
      expect(response).to have_http_status(:ok)
      expect(json).to include("crib_size")
    end
  end
end
