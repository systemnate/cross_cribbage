# app/controllers/api_controller.rb
# frozen_string_literal: true

class ApiController < ActionController::API
  before_action :set_current_token

  private

  def set_current_token
    @current_token = request.headers["X-Player-Token"] || params[:token]
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
  end
end
