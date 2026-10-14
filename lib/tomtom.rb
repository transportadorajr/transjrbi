module Tomtom
  class Error < StandardError
    attr_reader :status

    def initialize(message = nil, status: nil)
      super(message)
      @status = status
    end
  end

  class ConfigurationError < Error; end
  class RequestError < Error; end
  class RateLimitError < RequestError; end
  class NoRouteError < RequestError; end

  class << self
    def configured?
      Rails.application.credentials.dig(:tomtom, :api_key).present?
    end

    def api_key
      Rails.application.credentials.dig(:tomtom, :api_key).presence || raise(ConfigurationError, I18n.t('tomtom.errors.missing_api_key'))
    end
  end
end
