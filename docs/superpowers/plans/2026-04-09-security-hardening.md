# Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 7 security issues from the April 2026 audit by migrating to httpOnly cookie auth and adding CORS, CSP, and rate limiting hardening.

**Architecture:** Replace localStorage token + `X-Player-Token` header + cable `?token=` query param with a single server-set httpOnly cookie. The frontend never touches the token value again — the browser sends the cookie automatically on every request. CORS gains `credentials: true` and restricts `/cable` to allowed origins. CSP is enabled. `rack-attack` throttles game creation and general API traffic.

**Tech Stack:** Rails 8, RSpec, rack-attack gem, React 19, TypeScript

---

## File Map

| File | Change |
|---|---|
| `Gemfile` | add `rack-attack` |
| `app/controllers/api_controller.rb` | `include ActionController::Cookies`, read token from cookie, add `set_player_cookie` helper |
| `app/controllers/api/games_controller.rb` | call `set_player_cookie` on create/join, return only `game_id`, `with_lock` on join, `params.require` on place_card |
| `app/channels/application_cable/connection.rb` | read token from `cookies[:player_token]` |
| `config/initializers/cors.rb` | consolidate blocks, add `credentials: true`, restrict `/cable` origins |
| `config/initializers/content_security_policy.rb` | uncomment and configure |
| `config/initializers/rack_attack.rb` | new file — throttle rules |
| `config/application.rb` | `config.middleware.use Rack::Attack` |
| `spec/requests/games_spec.rb` | switch from header auth to cookie auth, add missing-params test |
| `app/frontend/lib/storage.ts` | remove `TOKEN_KEY`, `getToken`, `setToken` |
| `app/frontend/lib/api.ts` | add `credentials: 'include'`, remove `X-Player-Token` header |
| `app/frontend/lib/cable.ts` | remove `?token=` from cable URL |
| `app/frontend/types/game.ts` | remove `token` from `CreateGameResponse` |
| `app/frontend/components/HomePage.tsx` | remove `setToken` calls, update destructuring |

---

### Task 1: Add rack-attack gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add the gem**

In `Gemfile`, add after `gem "rack-cors"`:

```ruby
gem "rack-attack"
```

- [ ] **Step 2: Install**

```bash
bundle install
```

Expected: `Bundle complete!` with rack-attack listed.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: add rack-attack gem"
```

---

### Task 2: Update request specs for cookie auth

Write failing tests that describe the new cookie-based behavior. Replace header-based auth throughout.

**Files:**
- Modify: `spec/requests/games_spec.rb`

- [ ] **Step 1: Rewrite the spec file**

Replace the full contents of `spec/requests/games_spec.rb` with:

```ruby
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
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bundle exec rspec spec/requests/games_spec.rb
```

Expected: multiple failures — tests expecting cookie behavior but getting the old header-based behavior.

---

### Task 3: Implement backend cookie auth

**Files:**
- Modify: `app/controllers/api_controller.rb`
- Modify: `app/controllers/api/games_controller.rb`

- [ ] **Step 1: Update ApiController**

Replace the full contents of `app/controllers/api_controller.rb` with:

```ruby
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
```

- [ ] **Step 2: Update GamesController — create, join, place_card**

Replace the full contents of `app/controllers/api/games_controller.rb` with:

```ruby
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

      if params[:vs_computer]
        game.update!(player2_token: Game.generate_token, vs_computer: true)
        game.deal!
      end

      set_player_cookie(token)
      DestroyGameJob.set(wait: 2.hours).perform_later(game.id)
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
```

- [ ] **Step 3: Run the request specs**

```bash
bundle exec rspec spec/requests/games_spec.rb
```

Expected: all pass.

- [ ] **Step 4: Run the full suite to catch regressions**

```bash
bundle exec rspec
```

Expected: all pass (other specs don't use the HTTP layer for auth).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api_controller.rb \
        app/controllers/api/games_controller.rb \
        spec/requests/games_spec.rb
git commit -m "security: migrate to httpOnly cookie auth, lock join, require place_card params"
```

---

### Task 4: Update ApplicationCable::Connection

**Files:**
- Modify: `app/channels/application_cable/connection.rb`

No automated test covers this directly; correctness is verified by the app working end-to-end.

- [ ] **Step 1: Replace the connection file**

```ruby
# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :player_token

    def connect
      self.player_token = cookies[:player_token] || reject_unauthorized_connection
    end
  end
end
```

- [ ] **Step 2: Run the channel spec to confirm nothing breaks**

```bash
bundle exec rspec spec/channels/
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add app/channels/application_cable/connection.rb
git commit -m "security: read cable auth token from httpOnly cookie"
```

---

### Task 5: Update CORS

**Files:**
- Modify: `config/initializers/cors.rb`

- [ ] **Step 1: Replace the CORS initializer**

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "localhost:3036,localhost:5173").split(",")

    resource "/api/*",
             headers:     :any,
             methods:     %i[get post put patch delete options head],
             credentials: true

    resource "/cable",
             headers:     :any,
             methods:     %i[get],
             credentials: true
  end
end
```

- [ ] **Step 2: Run the full spec suite**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add config/initializers/cors.rb
git commit -m "security: restrict CORS origins for /cable, add credentials: true"
```

---

### Task 6: Enable Content Security Policy

**Files:**
- Modify: `config/initializers/content_security_policy.rb`

- [ ] **Step 1: Replace the CSP initializer**

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
      vite_ws   = "ws://#{ViteRuby.config.host_with_port}"
      policy.script_src  *policy.script_src, :unsafe_eval, vite_host
      policy.style_src   *policy.style_src, vite_host
      policy.connect_src *policy.connect_src, vite_host, vite_ws, "ws://localhost:3036"
    end
  end
end
```

- [ ] **Step 2: Run specs**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add config/initializers/content_security_policy.rb
git commit -m "security: enable Content Security Policy"
```

---

### Task 7: Add Rack::Attack rate limiting

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Modify: `config/application.rb`

- [ ] **Step 1: Create the Rack::Attack initializer**

Create `config/initializers/rack_attack.rb`:

```ruby
# frozen_string_literal: true

Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api")
end

Rack::Attack.throttle("game_create/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/api/games" && req.post?
end
```

- [ ] **Step 2: Mount the middleware in application.rb**

In `config/application.rb`, add inside the `Application` class body (after `config.autoload_lib`):

```ruby
config.middleware.use Rack::Attack
```

- [ ] **Step 3: Run specs**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add config/initializers/rack_attack.rb config/application.rb
git commit -m "security: add Rack::Attack rate limiting for game creation and API"
```

---

### Task 8: Frontend — remove token from JS, drop cable query param

**Files:**
- Modify: `app/frontend/lib/storage.ts`
- Modify: `app/frontend/lib/api.ts`
- Modify: `app/frontend/lib/cable.ts`
- Modify: `app/frontend/types/game.ts`
- Modify: `app/frontend/components/HomePage.tsx`

- [ ] **Step 1: Update storage.ts — remove token functions**

Replace the full file:

```typescript
// app/frontend/lib/storage.ts
const GAME_KEY = "ccg_game_id";

export const getGameId     = (): string | null => localStorage.getItem(GAME_KEY);
export const setGameId     = (id: string): void => { localStorage.setItem(GAME_KEY, id); };
export const clearSession  = (): void => { localStorage.removeItem(GAME_KEY); };
```

- [ ] **Step 2: Update api.ts — credentials: include, drop header**

Replace the full file:

```typescript
// app/frontend/lib/api.ts
import type { GameState, CreateGameResponse } from "../types/game";

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`/api${path}`, {
    method,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error ?? "Request failed");
  }

  return res.json() as Promise<T>;
}

export const api = {
  createGame: (options?: { vs_computer?: boolean }): Promise<CreateGameResponse> =>
    request("POST", "/games", options),

  joinGame: (id: string): Promise<CreateGameResponse> =>
    request("POST", `/games/${id}/join`),

  getGame: (id: string): Promise<GameState> =>
    request("GET", `/games/${id}`),

  placeCard: (id: string, row: number, col: number): Promise<GameState> =>
    request("POST", `/games/${id}/place_card`, { row, col }),

  discardToCrib: (id: string): Promise<GameState> =>
    request("POST", `/games/${id}/discard_to_crib`),

  confirmRound: (id: string): Promise<GameState> =>
    request("POST", `/games/${id}/confirm_round`),
};
```

- [ ] **Step 3: Update cable.ts — drop token query param**

Replace the full file:

```typescript
// app/frontend/lib/cable.ts
import { createConsumer } from "@rails/actioncable";

type Consumer = ReturnType<typeof createConsumer>;

let consumer: Consumer | null = null;

export function getConsumer(): Consumer {
  if (!consumer) consumer = createConsumer("/cable");
  return consumer;
}

export function resetConsumer(): void {
  if (consumer) { consumer.disconnect(); consumer = null; }
}
```

- [ ] **Step 4: Update types/game.ts — remove token from CreateGameResponse**

In `app/frontend/types/game.ts`, replace:

```typescript
export interface CreateGameResponse {
  game_id: string;
  token: string;
}
```

with:

```typescript
export interface CreateGameResponse {
  game_id: string;
}
```

- [ ] **Step 5: Update HomePage.tsx — remove setToken calls**

Replace the full file:

```typescript
import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { setGameId, clearSession } from "../lib/storage";
import { resetConsumer } from "../lib/cable";

export function HomePage() {
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [createdGameId, setCreatedGameId] = useState<string | null>(null);

  const createGame = useMutation({
    mutationFn: api.createGame,
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      setCreatedGameId(game_id);
    },
    onError: (e: Error) => setError(e.message),
  });

  const playComputer = useMutation({
    mutationFn: () => api.createGame({ vs_computer: true }),
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  const joinGame = useMutation({
    mutationFn: () => api.joinGame(joinId.trim()),
    onMutate: () => setError(null),
    onSuccess: ({ game_id }) => {
      clearSession();
      resetConsumer();
      setGameId(game_id);
      navigate(`/game/${game_id}`);
    },
    onError: (e: Error) => setError(e.message),
  });

  if (createdGameId) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
        <h1 className="text-3xl font-black text-green-400">Game created!</h1>
        <p className="text-slate-400 text-sm">Share this ID with your opponent:</p>
        <div className="bg-slate-800 border border-slate-600 rounded-lg px-6 py-3 font-mono text-yellow-300 text-sm select-all">
          {createdGameId}
        </div>
        <p className="text-slate-500 text-xs">Waiting for opponent to join…</p>
        <button
          onClick={() => navigate(`/game/${createdGameId}`)}
          className="rounded-lg bg-slate-700 hover:bg-slate-600 text-slate-100 font-semibold px-5 py-2 text-sm"
        >
          Go to game
        </button>
      </div>
    );
  }

  const anyPending = createGame.isPending || playComputer.isPending || joinGame.isPending;

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-6 p-6">
      <h1 className="text-4xl font-black tracking-wide text-yellow-400">Cross Cribbage</h1>
      <p className="text-slate-400 text-sm">Real-time two-player cribbage on a 5×5 board</p>

      {error && <p className="text-red-400 text-xs">{error}</p>}

      <div className="flex flex-col gap-4 w-full max-w-sm">
        <div className="flex gap-2">
          <button
            onClick={() => createGame.mutate()}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-yellow-400 hover:bg-yellow-300 disabled:opacity-50 text-slate-900 font-bold py-3 text-sm transition-colors"
          >
            {createGame.isPending ? "Creating…" : "Start New Game"}
          </button>
          <button
            onClick={() => playComputer.mutate()}
            disabled={anyPending}
            className="flex-1 rounded-lg bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white font-bold py-3 text-sm transition-colors"
          >
            {playComputer.isPending ? "Starting…" : "Play Computer"}
          </button>
        </div>

        <div className="flex items-center gap-2 text-slate-600 text-xs">
          <hr className="flex-1 border-slate-700" /><span>or</span><hr className="flex-1 border-slate-700" />
        </div>

        <div className="flex gap-2">
          <input
            type="text"
            placeholder="Paste Game ID"
            value={joinId}
            onChange={(e) => setJoinId(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && joinGame.mutate()}
            className="flex-1 rounded-lg bg-slate-800 border border-slate-700 text-slate-100 text-sm px-3 py-2 focus:outline-none focus:border-yellow-400"
          />
          <button
            onClick={() => joinGame.mutate()}
            disabled={anyPending || !joinId.trim()}
            className="rounded-lg bg-slate-700 hover:bg-slate-600 disabled:opacity-50 text-slate-100 font-semibold px-4 py-2 text-sm"
          >
            {joinGame.isPending ? "Joining…" : "Join"}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 6: Check TypeScript compiles cleanly**

```bash
cd app/frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 7: Run specs one final time**

```bash
bundle exec rspec
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add app/frontend/lib/storage.ts \
        app/frontend/lib/api.ts \
        app/frontend/lib/cable.ts \
        app/frontend/types/game.ts \
        app/frontend/components/HomePage.tsx
git commit -m "security: frontend — remove token from JS, drop cable query param"
```
