module Discord
  class Error < StandardError; end

  class << self
    def configured?
      error_webhook_url.present?
    end

    def error_webhook_url
      Rails.application.credentials.dig(:discord, :error_webhook_url)
    end
  end
end
