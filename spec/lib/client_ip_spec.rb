# spec/lib/client_ip_spec.rb
require "rails_helper"

RSpec.describe ClientIp do
  def request_with(env)
    Rack::Request.new(Rack::MockRequest.env_for("/api/games", env))
  end

  describe ".key_for" do
    it "prefers Fly-Client-IP over the Rack-resolved IP" do
      req = request_with(
        "REMOTE_ADDR"          => "fdaa:0:1::3",
        "HTTP_X_FORWARDED_FOR" => "9.9.9.9, 203.0.113.7",
        "HTTP_FORWARDED"       => "for=198.51.100.110",
        "HTTP_FLY_CLIENT_IP"   => "203.0.113.7"
      )
      expect(described_class.key_for(req)).to eq("203.0.113.7")
    end

    it "falls back to the Rack-resolved IP when Fly-Client-IP is absent" do
      req = request_with("REMOTE_ADDR" => "203.0.113.9")
      expect(described_class.key_for(req)).to eq("203.0.113.9")
    end

    it "buckets IPv6 clients by /64 prefix" do
      a = request_with("HTTP_FLY_CLIENT_IP" => "2001:db8:1:2::1")
      b = request_with("HTTP_FLY_CLIENT_IP" => "2001:db8:1:2:abcd:ef01:2345:6789")
      c = request_with("HTTP_FLY_CLIENT_IP" => "2001:db8:1:3::1")

      expect(described_class.key_for(a)).to eq("2001:db8:1:2::/64")
      expect(described_class.key_for(b)).to eq(described_class.key_for(a))
      expect(described_class.key_for(c)).not_to eq(described_class.key_for(a))
    end
  end

  describe ".normalize" do
    it "leaves IPv4 addresses unchanged" do
      expect(described_class.normalize("203.0.113.7")).to eq("203.0.113.7")
    end

    it "unwraps IPv4-mapped IPv6 addresses" do
      expect(described_class.normalize("::ffff:203.0.113.7")).to eq("203.0.113.7")
    end

    it "returns unparseable values unchanged" do
      expect(described_class.normalize("not-an-ip")).to eq("not-an-ip")
    end

    it "returns nil for a blank value" do
      expect(described_class.normalize(nil)).to be_nil
    end
  end
end
