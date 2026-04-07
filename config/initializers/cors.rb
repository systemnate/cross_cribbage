Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "localhost:3036,localhost:5173").split(",")
    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head]
  end

  allow do
    origins "*"
    resource "/cable", headers: :any, methods: %i[get]
  end
end
