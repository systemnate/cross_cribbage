# frozen_string_literal: true

# Broad API rate limit
Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api")
end

# Per-IP game creation: 3 per hour.
# A human creating 3 games/hr from one IP is generous; bots cycling IPs still
# hit the global waiting-game cap as the real backstop.
Rack::Attack.throttle("game_create/ip", limit: 3, period: 1.hour) do |req|
  req.ip if req.path == "/api/games" && req.post?
end

# Per-cookie game creation: 2 per hour.
# Bots that reuse their received cookie are throttled here in addition to IP.
# Requests with no cookie fall through; IP throttle still applies.
Rack::Attack.throttle("game_create/cookie", limit: 2, period: 1.hour) do |req|
  if req.path == "/api/games" && req.post?
    cookie_header = req.env["HTTP_COOKIE"] || ""
    token = cookie_header[/(?:^|;\s*)player_token=([^;]+)/, 1]
    token.presence
  end
end

# Return a JSON 429 body (app is API-only).
Rack::Attack.throttled_responder = lambda do |_env|
  [429, { "Content-Type" => "application/json" },
   ['{"error":"Too many requests. Please slow down."}']]
end
