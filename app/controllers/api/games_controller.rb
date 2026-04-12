# app/controllers/api/games_controller.rb
# frozen_string_literal: true

module Api
  class GamesController < ApiController
    GAME_ACTIONS = %i[show place_card discard_to_crib confirm_round].freeze
    WAITING_GAME_CAP = 50

    before_action :set_game,          only: [:join, :destroy] + GAME_ACTIONS
    before_action :authorize_player!, only: GAME_ACTIONS

    # POST /api/games
    def create
      if Game.where(status: "waiting").count >= WAITING_GAME_CAP
        return render json: { error: "Server is busy, please try again later." },
                      status: :service_unavailable
      end

      if @current_token.present? &&
         Game.exists?(player1_token: @current_token, status: "waiting")
        return render json: { error: "You already have a game waiting for a player." },
                      status: :conflict
      end

      token = Game.generate_token
      game  = Game.create!(player1_token: token)

      if params[:vs_computer]
        game.update!(player2_token: Game.generate_token, vs_computer: true)
        game.deal!
        DestroyGameJob.set(wait: 2.hours).perform_later(game.id)
      else
        DestroyGameJob.set(wait: 30.minutes).perform_later(game.id)
      end

      set_player_cookie(token)
      render json: { game_id: game.id }, status: :created
    end

    # POST /api/games/:id/join
    def join
      @game.with_lock do
        return render_error("Game is not joinable")         unless @game.status == "waiting"
        return render_error("Game already has two players") if @game.player2_token.present?
        return render_error("Cannot join your own game", status: :forbidden) if @current_token == @game.player1_token

        token = Game.generate_token
        set_player_cookie(token)
        @game.update!(player2_token: token)
        @game.deal!
        DestroyGameJob.set(wait: 2.hours).perform_later(@game.id)
        GameChannel.broadcast_game_state(@game)
        render json: { game_id: @game.id }, status: :ok
      end
    end

    # GET /api/games/:id
    def show
      render json: @game.serialize_for(@current_token)
    end

    # POST /api/games/:id/place_card  { row: int, col: int }
    def place_card
      row = params.require(:row).to_i
      col = params.require(:col).to_i
      game_action do
        @game.place_card!(current_slot, row, col)
        if @game.status == "scoring" && !@game.vs_computer?
          AdvanceRoundJob.set(wait: 10.seconds).perform_later(@game.id)
        end
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

    # DELETE /api/games/:id
    def destroy
      unless @current_token.present?
        return render_error("Unauthorized", status: :unauthorized)
      end

      slot = @game.player_slot(@current_token)
      unless slot
        return render_error("Unauthorized", status: :unauthorized)
      end

      @game.with_lock do
        unless can_destroy?(@game, slot)
          return render_error(
            "Can't end an active game against another player",
            status: :unprocessable_entity
          )
        end

        @game.destroy!
      end
      render json: { ok: true }
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

    def can_destroy?(game, slot)
      return true if game.vs_computer? && slot == "player1"
      return true if game.status == "finished"
      return true if game.status == "waiting" && slot == "player1"
      false
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
