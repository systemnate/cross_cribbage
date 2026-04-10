# spec/requests/games_spec.rb
require "rails_helper"

RSpec.describe "Api::Games", type: :request do
  def json = JSON.parse(response.body)

  describe "POST /api/games" do
    it "creates a game, sets an httpOnly cookie, and returns only game_id" do
      post "/api/games"
      expect(response).to have_http_status(:created)
      expect(json.keys).to include("game_id")
      expect(json.keys).not_to include("token")
      expect(response.cookies["player_token"]).to be_present
    end

    it "creates a vs-computer game that is immediately active" do
      post "/api/games", params: { vs_computer: true }, as: :json
      expect(response).to have_http_status(:created)
      expect(json.keys).to include("game_id")
      expect(response.cookies["player_token"]).to be_present

      game = Game.find(json["game_id"])
      expect(game.vs_computer).to be(true)
      expect(game.status).to eq("active")
      expect(game.player2_token).to be_present
    end
  end

  describe "POST /api/games/:id/join" do
    let(:game) { create(:game) }

    it "sets cookie for player 2 and starts the game" do
      post "/api/games/#{game.id}/join"
      expect(response).to have_http_status(:ok)
      expect(json.keys).to include("game_id")
      expect(json.keys).not_to include("token")
      expect(response.cookies["player_token"]).to be_present
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

    it "returns game state for an authenticated player (cookie auth)" do
      cookies[:player_token] = game.player1_token
      get "/api/games/#{game.id}"
      expect(response).to have_http_status(:ok)
      expect(json).to include("status", "board", "my_slot", "my_next_card")
      expect(json["my_slot"]).to eq("player1")
    end

    it "returns my_next_card scoped to the requesting player" do
      cookies[:player_token] = game.player2_token
      get "/api/games/#{game.id}"
      expect(json["my_slot"]).to eq("player2")
      expect(json["my_next_card"]).to be_a(Hash)
    end

    it "returns 401 without a cookie" do
      get "/api/games/#{game.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/games/:id/place_card" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    it "places the card and returns updated state" do
      cookies[:player_token] = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/place_card", params: { row: 0, col: 0 }
      expect(response).to have_http_status(:ok)
      expect(json["board"][0][0]).to be_a(Hash)
    end

    it "returns error for wrong player" do
      other_slot = game.current_turn == "player1" ? "player2" : "player1"
      cookies[:player_token] = game.send("#{other_slot}_token")
      post "/api/games/#{game.id}/place_card", params: { row: 0, col: 0 }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without a cookie" do
      post "/api/games/#{game.id}/place_card", params: { row: 0, col: 0 }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 400 when row param is missing" do
      cookies[:player_token] = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/place_card", params: { col: 0 }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when col param is missing" do
      cookies[:player_token] = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/place_card", params: { row: 0 }
      expect(response).to have_http_status(:bad_request)
    end

    it "does not enqueue AdvanceRoundJob on a mid-game card placement" do
      cookies[:player_token] = game.send("#{game.current_turn}_token")
      expect {
        post "/api/games/#{game.id}/place_card", params: { row: 0, col: 0 }
      }.not_to have_enqueued_job(AdvanceRoundJob)
    end
  end

  describe "POST /api/games/:id/discard_to_crib" do
    let(:game) { create(:game, :active) }

    before { game.deal!; game.reload }

    it "discards to crib and returns updated state" do
      cookies[:player_token] = game.send("#{game.current_turn}_token")
      post "/api/games/#{game.id}/discard_to_crib"
      expect(response).to have_http_status(:ok)
      expect(json).to include("crib_size")
    end
  end

  describe "POST /api/games/:id/confirm_round" do
    let(:game) { create(:game, :active) }

    before do
      game.deal!
      game.reload
      game.update!(status: "scoring")
    end

    it "sets the confirming player's flag and returns ok" do
      cookies[:player_token] = game.player1_token
      post "/api/games/#{game.id}/confirm_round"
      expect(response).to have_http_status(:ok)
      expect(game.reload.player1_confirmed_scoring).to be true
    end

    it "advances the round immediately when both players confirm" do
      cookies[:player_token] = game.player1_token
      post "/api/games/#{game.id}/confirm_round"
      cookies[:player_token] = game.player2_token
      post "/api/games/#{game.id}/confirm_round"
      expect(response).to have_http_status(:ok)
      expect(game.reload.status).to eq("active")
      expect(game.reload.round).to eq(2)
    end

    it "returns error when called outside scoring phase" do
      non_scoring = create(:game, :active)
      non_scoring.deal!
      non_scoring.reload
      cookies[:player_token] = non_scoring.player1_token
      post "/api/games/#{non_scoring.id}/confirm_round"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without a cookie" do
      post "/api/games/#{game.id}/confirm_round"
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not enqueue AdvanceRoundJob when only one player confirms" do
      cookies[:player_token] = game.player1_token
      expect {
        post "/api/games/#{game.id}/confirm_round"
      }.not_to have_enqueued_job(AdvanceRoundJob)
    end
  end

  describe "DELETE /api/games/:id" do
    let(:game) { create(:game) }

    it "destroys a waiting game when called by the creator" do
      cookies[:player_token] = game.player1_token
      delete "/api/games/#{game.id}"
      expect(response).to have_http_status(:ok)
      expect(json).to eq("ok" => true)
      expect(Game.exists?(game.id)).to be false
    end

    it "returns 403 when called by someone other than the creator" do
      cookies[:player_token] = "not-the-creator-token"
      delete "/api/games/#{game.id}"
      expect(response).to have_http_status(:forbidden)
      expect(Game.exists?(game.id)).to be true
    end

    it "returns 422 when the game is not in waiting status" do
      active_game = create(:game, :active)
      active_game.deal!
      active_game.reload
      cookies[:player_token] = active_game.player1_token
      delete "/api/games/#{active_game.id}"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Game.exists?(active_game.id)).to be true
    end

    it "returns 401 without a cookie" do
      delete "/api/games/#{game.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for a non-existent game" do
      cookies[:player_token] = game.player1_token
      delete "/api/games/#{SecureRandom.uuid}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
