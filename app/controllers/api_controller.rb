# app/controllers/api_controller.rb
# frozen_string_literal: true

class ApiController < ActionController::API
  include ActionController::Cookies

  before_action :set_current_token

  private

  def set_current_token
    @current_token = cookies[:player_token]
  end

  def set_player_cookie(token)
    cookies[:player_token] = {
      value:     token,
      httponly:  true,
      secure:    Rails.env.production?,
      same_site: :strict,
      expires:   2.hours.from_now
    }
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
  end
end
