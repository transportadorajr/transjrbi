Sentry.init do |config|
  config.dsn = ENV.fetch('SENTRY_DSN') { Rails.application.credentials.dig(:sentry, :dsn) }
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.send_default_pii = false
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0).to_f
end
