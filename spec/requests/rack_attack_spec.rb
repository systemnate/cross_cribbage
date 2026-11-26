# spec/requests/rack_attack_spec.rb
require "rails_helper"

# The test env uses :null_store, so give Rack::Attack a real store here.
RSpec.describe "Rack::Attack throttles", type: :request do
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store = original_store
  end

  # 10 game creations per client per hour (game_create/ip).
  CREATE_LIMIT = 10
  THROTTLED_BODY = { "error" => "Too many requests. Please slow down." }.freeze

  # vs-computer games start active, so the waiting-game caps never interfere
  # with counting requests against the throttle.
  def create_game(headers = {}, env = {})
    cookies.delete("player_token")
    post "/api/games", params: { vs_computer: true }, as: :json, headers: headers, env: env
    response
  end

  it "keys game creation on Fly-Client-IP, not the connecting proxy address" do
    CREATE_LIMIT.times do |i|
      expect(create_game({ "Fly-Client-IP" => "203.0.113.7" }, { "REMOTE_ADDR" => "fdaa:0:1::#{i + 1}" }))
        .to have_http_status(:created)
    end

    expect(create_game({ "Fly-Client-IP" => "203.0.113.7" }, { "REMOTE_ADDR" => "fdaa:0:1::99" }))
      .to have_http_status(:too_many_requests)
    expect(JSON.parse(response.body)).to eq(THROTTLED_BODY)

    expect(create_game({ "Fly-Client-IP" => "203.0.113.8" })).to have_http_status(:created)
  end

  it "ignores a spoofed Forwarded header when Fly-Client-IP is present" do
    CREATE_LIMIT.times do |i|
      expect(create_game(
        { "Fly-Client-IP" => "203.0.113.7", "Forwarded" => "for=198.51.100.#{i + 1}" },
        { "REMOTE_ADDR" => "fdaa:0:1::3" }
      )).to have_http_status(:created)
    end

    expect(create_game(
      { "Fly-Client-IP" => "203.0.113.7", "Forwarded" => "for=198.51.100.200" },
      { "REMOTE_ADDR" => "fdaa:0:1::3" }
    )).to have_http_status(:too_many_requests)
  end

  it "throttles rotating IPv6 addresses within the same /64 together" do
    CREATE_LIMIT.times do |i|
      expect(create_game({ "Fly-Client-IP" => "2001:db8:1:2::#{(i + 1).to_s(16)}" }))
        .to have_http_status(:created)
    end

    expect(create_game({ "Fly-Client-IP" => "2001:db8:1:2:ffff::1" }))
      .to have_http_status(:too_many_requests)
    expect(create_game({ "Fly-Client-IP" => "2001:db8:1:3::1" })).to have_http_status(:created)
  end
end
