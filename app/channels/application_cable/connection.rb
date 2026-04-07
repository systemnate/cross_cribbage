module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :player_token

    def connect
      self.player_token = request.params[:token] || reject_unauthorized_connection
    end
  end
end
