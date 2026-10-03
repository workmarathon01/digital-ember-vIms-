# Allow the Next.js frontend (localhost:3002) to call the JSON API.
# Adjust CORS_ALLOWED_ORIGINS at deploy time.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:3002,http://127.0.0.1:3002").split(",")

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[WWW-Authenticate],
      max_age: 600
  end
end
