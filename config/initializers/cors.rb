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
