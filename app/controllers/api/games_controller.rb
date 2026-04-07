# app/controllers/api/games_controller.rb
# frozen_string_literal: true

module Api
  class GamesController < ApiController
    GAME_ACTIONS = %i[show place_card discard_to_crib].freeze

    before_action :set_game,          only: [:join] + GAME_ACTIONS
    before_action :authorize_player!, only: GAME_ACTIONS

    # POST /api/games
    def create
      token = Game.generate_token
      game  = Game.create!(player1_token: token)
      render json: { game_id: game.id, token: token }, status: :created
    end

    # POST /api/games/:id/join
    def join
      return render_error("Game is not joinable")         unless @game.status == "waiting"
      return render_error("Game already has two players") if @game.player2_token.present?

      token = Game.generate_token
      @game.update!(player2_token: token)
      @game.deal!
      GameChannel.broadcast_game_state(@game)
      render json: { game_id: @game.id, token: token }, status: :ok
    end

    # GET /api/games/:id
    def show
      render json: @game.serialize_for(@current_token)
    end

    # POST /api/games/:id/place_card  { row: int, col: int }
    def place_card
      game_action { @game.place_card!(current_slot, params[:row].to_i, params[:col].to_i) }
    end

    # POST /api/games/:id/discard_to_crib
    def discard_to_crib
      game_action { @game.discard_to_crib!(current_slot) }
    end

    private

    def set_game
      @game = Game.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_error("Game not found", status: :not_found)
    end

    def authorize_player!
      return if @game.player1_token == @current_token ||
                @game.player2_token == @current_token

      render_error("Unauthorized", status: :unauthorized)
    end

    def current_slot
      @game.player_slot(@current_token)
    end

    def game_action(&block)
      block.call
      if @game.status == "scoring" && @game.winner_slot.nil?
        AdvanceRoundJob.set(wait: 3.seconds).perform_later(@game.id)
      end
      GameChannel.broadcast_game_state(@game)
      render json: @game.serialize_for(@current_token)
    rescue Game::Error => e
      render_error(e.message)
    end
  end
end
