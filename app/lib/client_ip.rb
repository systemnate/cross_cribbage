# frozen_string_literal: true

require "ipaddr"

# Derives a stable per-client key for rate limiting and abuse caps.
#
# Fly's edge sets Fly-Client-IP to the real client address and a client
# can't override it. We prefer it over Rack's #ip, which honours a
# client-supplied RFC 7239 Forwarded header behind Fly's private-network
# proxy. IPv6 addresses are bucketed by their /64 prefix, because a single
# subscriber typically controls a whole /64 and can rotate freely inside it.
module ClientIp
  IPV6_PREFIX_LENGTH = 64

  module_function

  def key_for(request)
    ip = request.get_header("HTTP_FLY_CLIENT_IP").presence || request.ip
    normalize(ip)
  end

  def normalize(ip)
    return ip if ip.blank?

    addr = IPAddr.new(ip.to_s.strip)
    return addr.native.to_s if addr.ipv4_mapped?
    return addr.to_s unless addr.ipv6?

    "#{addr.mask(IPV6_PREFIX_LENGTH)}/#{IPV6_PREFIX_LENGTH}"
  rescue IPAddr::Error
    ip.to_s.strip
  end
end
