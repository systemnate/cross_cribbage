# frozen_string_literal: true

Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api")
end

Rack::Attack.throttle("game_create/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/api/games" && req.post?
end
