# Security Hardening Design

**Date:** 2026-04-09
**Scope:** Fix all critical and high security issues identified in the April 2026 audit.

---

## Problems Being Solved

| # | Issue | Severity |
|---|---|---|
| 1 | Player token passed as `?token=` query param in WebSocket URL — logged by servers and CDNs | Critical |
| 2 | Player token stored in `localStorage` — accessible to any JavaScript | Critical |
| 3 | Race condition on game join — no DB-level locking | Critical |
| 4 | CORS allows `origins "*"` on `/cable` | High |
| 5 | CSP disabled — no protection against XSS or injected scripts | High |
| 6 | No rate limiting — game creation and API endpoints are unprotected | High |
| 7 | `place_card` silently treats missing `row`/`col` params as `0` | Medium |

---

## Solution: httpOnly Cookie Auth Migration

Replace the localStorage token + `X-Player-Token` header + cable query param pattern with a single httpOnly cookie that the browser manages automatically.

---

## Backend Changes

### 1. `ApiController` — cookie support and token reading

Add `include ActionController::Cookies` (not included in `ActionController::API` by default).

Change `set_current_token` to read from the cookie instead of the header:

```ruby
def set_current_token
  @current_token = cookies[:player_token]
end
```

### 2. `Api::GamesController` — set cookie on create and join

On `create`:
- Generate token as before
- Set `cookies[:player_token]` with httpOnly, Secure (production only), SameSite=Strict, 2-hour expiry
- Return only `{ game_id: }` in JSON — do not return the raw token

On `join`:
- Same cookie-setting logic
- Return only `{ game_id: }` in JSON

Cookie attributes:
```ruby
cookies[:player_token] = {
  value:     token,
  httponly:  true,
  secure:    Rails.env.production?,
  same_site: :strict,
  expires:   2.hours.from_now
}
```

### 3. `ApplicationCable::Connection` — read token from cookie

```ruby
def connect
  self.player_token = cookies[:player_token] || reject_unauthorized_connection
end
```

ActionCable connections have access to the request cookie jar — no middleware change needed.

### 4. CORS (`config/initializers/cors.rb`)

- Delete the wildcard `origins "*"` block for `/cable`
- Add `/cable` to the existing restricted-origins block
- Add `credentials: true` to both resources so cookies are included in cross-origin requests

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "localhost:3036,localhost:5173").split(",")
    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
    resource "/cable",
             headers: :any,
             methods: %i[get],
             credentials: true
  end
end
```

### 5. CSP (`config/initializers/content_security_policy.rb`)

Uncomment and configure:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.object_src  :none
    policy.img_src     :self, :data
    policy.style_src   :self, :unsafe_inline
    policy.script_src  :self
    policy.connect_src :self, "wss://cross-cribbage.fly.dev"

    if Rails.env.development?
      vite_host = "http://#{ViteRuby.config.host_with_port}"
      policy.script_src *policy.script_src, :unsafe_eval, vite_host
      policy.style_src  *policy.style_src, vite_host
      policy.connect_src *policy.connect_src, vite_host,
                         "ws://#{ViteRuby.config.host_with_port}",
                         "ws://localhost:3036"
    end
  end
end
```

### 6. Rate limiting (`Gemfile` + `config/initializers/rack_attack.rb`)

Add `gem "rack-attack"` to Gemfile.

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api")
end

Rack::Attack.throttle("game_create/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/api/games" && req.post?
end
```

Mount middleware in `config/application.rb`:
```ruby
config.middleware.use Rack::Attack
```

### 7. Join race condition (`app/controllers/api/games_controller.rb`)

Wrap the join body in a database-level lock:

```ruby
def join
  @game.with_lock do
    return render_error("Game is not joinable")         unless @game.status == "waiting"
    return render_error("Game already has two players") if @game.player2_token.present?
    return render_error("Cannot join your own game", status: :forbidden) if @current_token == @game.player1_token

    token = Game.generate_token
    set_player_cookie(token)
    @game.update!(player2_token: token)
    @game.deal!
    GameChannel.broadcast_game_state(@game)
    render json: { game_id: @game.id }, status: :ok
  end
end
```

A private `set_player_cookie(token)` helper will be extracted in `ApiController` (or `GamesController`) to avoid duplicating cookie attributes across `create` and `join`.

### 8. `place_card` param validation

```ruby
def place_card
  row = params.require(:row).to_i
  col = params.require(:col).to_i
  game_action do
    @game.place_card!(current_slot, row, col)
    ...
  end
end
```

---

## Frontend Changes

### `app/frontend/lib/storage.ts`

Remove `TOKEN_KEY`, `getToken`, `setToken`. Keep `getGameId`, `setGameId`, `clearSession` (clears game ID from localStorage only — the cookie expires on its own).

### `app/frontend/lib/api.ts`

- Add `credentials: 'include'` to all fetch calls (required for cross-origin cookie sending)
- Remove the `X-Player-Token` header
- `createGame` and `joinGame` now return only `{ game_id }` — no token to store

### `app/frontend/lib/cable.ts`

`cableUrl()` returns `/cable` — no token query param.

### Call sites (`HomePage.tsx` and any other location that calls `setToken`)

Remove all `setToken(response.token)` calls. The cookie is set server-side.

Any code that called `getToken()` to check whether the user has an active session should be removed or replaced with a try/catch around `api.getGame()`.

---

## What Is Not Changed

- Game IDs remain in `localStorage` (not sensitive — a game ID without a matching token is useless)
- Token generation (`SecureRandom.hex(16)`) — already cryptographically secure
- The `authorize_player!` before_action — still correct
- `GameChannel` broadcast payload — already safe (no secret card data exposed)

---

## Open Questions / Assumptions

- **Dev HTTPS**: `secure: Rails.env.production?` means the cookie is not Secure in development. This is intentional — forcing HTTPS in local dev adds friction. Acceptable trade-off.
- **`ALLOWED_ORIGINS` in production**: The Fly.io deployment must set this env var to `cross-cribbage.fly.dev` (or whatever the production domain is). Without it, the default includes only localhost, which would break production CORS.
- **Cookie expiry**: Set to 2 hours, matching `DestroyGameJob`. After the game is destroyed, the cookie is expired anyway.
