# app/controllers/api/games_controller.rb
# frozen_string_literal: true

module Api
  class GamesController < ApiController
    GAME_ACTIONS = %i[show place_card discard_to_crib confirm_round].freeze

    before_action :set_game,          only: [:join] + GAME_ACTIONS
    before_action :authorize_player!, only: GAME_ACTIONS

    # POST /api/games
    def create
      token = Game.generate_token
      game  = Game.create!(player1_token: token)
      DestroyGameJob.set(wait: 2.hours).perform_later(game.id)
      render json: { game_id: game.id, token: token }, status: :created
    end

    # POST /api/games/:id/join
    def join
      return render_error("Game is not joinable")         unless @game.status == "waiting"
      return render_error("Game already has two players") if @game.player2_token.present?
      return render_error("Cannot join your own game", status: :forbidden) if @current_token == @game.player1_token

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
      game_action do
        @game.place_card!(current_slot, params[:row].to_i, params[:col].to_i)
        AdvanceRoundJob.set(wait: 10.seconds).perform_later(@game.id) if @game.status == "scoring"
      end
    end

    # POST /api/games/:id/discard_to_crib
    def discard_to_crib
      game_action { @game.discard_to_crib!(current_slot) }
    end

    # POST /api/games/:id/confirm_round
    def confirm_round
      game_action do
        @game.with_lock do
          @game.confirm_scoring!(current_slot)
          @game.advance_round! if @game.both_scoring_confirmed?
        end
        @game.reload
      end
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
      GameChannel.broadcast_game_state(@game)
      render json: @game.serialize_for(@current_token)
    rescue Game::Error => e
      render_error(e.message)
    end
  end
end
