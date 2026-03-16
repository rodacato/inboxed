Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("DASHBOARD_URL", "http://localhost:5179")

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true

    resource "/admin/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true

    resource "/auth/*",
      headers: :any,
      methods: [:get, :post, :put, :delete, :options, :head],
      credentials: true

    resource "/setup",
      headers: :any,
      methods: [:get, :post, :options],
      credentials: true

    resource "/site_admin/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true

    resource "/cable",
      headers: :any,
      methods: [:get, :options],
      credentials: true
  end
end
