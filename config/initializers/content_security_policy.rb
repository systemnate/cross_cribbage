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
      policy.script_src  *policy.script_src, :unsafe_inline, :unsafe_eval, vite_host
      policy.style_src   *policy.style_src, vite_host
      policy.connect_src *policy.connect_src, vite_host, vite_ws, "ws://localhost:3036"
    end
  end
end
