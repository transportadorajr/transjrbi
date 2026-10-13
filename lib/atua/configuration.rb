module Atua
  class Configuration
    KEYS = %i[base_url username password].freeze
    BASE_URL_ENV = 'ATUA_BASE_URL'.freeze
    LOCAL_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

    attr_reader :base_url, :username, :password

    class << self
      def for(tenant = nil, allow_remote_host: false)
        credentials = Rails.application.credentials.atua || {}

        configuration = new(
          base_url: base_url_for(tenant, credentials),
          username: credentials[:username],
          password: credentials[:password],
        )
        configuration.ensure_allowed_host! unless allow_remote_host

        configuration
      end

      private

      def base_url_for(tenant, credentials)
        return ENV[BASE_URL_ENV] if Rails.env.development? && ENV[BASE_URL_ENV].present?

        tenant&.atua_url.presence || credentials[:base_url]
      end
    end

    def initialize(base_url:, username:, password:)
      @base_url = base_url.to_s.strip.delete_suffix('/')
      @username = username.to_s
      @password = password.to_s

      ensure_complete!
    end

    def origin
      uri = URI.parse(base_url)
      default_port = uri.port == uri.default_port

      default_port ? "#{uri.scheme}://#{uri.host}" : "#{uri.scheme}://#{uri.host}:#{uri.port}"
    end

    def host
      URI.parse(base_url).host
    end

    def local?
      LOCAL_HOSTS.include?(host.to_s.delete_prefix('[').delete_suffix(']'))
    end

    def ensure_allowed_host!
      return if Rails.env.production? || local?

      raise ConfigurationError, I18n.t('atua.errors.remote_host_blocked', host:)
    end

    def inspect
      "#<#{self.class.name} base_url=#{base_url.inspect} username=#{username.inspect} password=[FILTERED]>"
    end

    private

    def ensure_complete!
      missing = KEYS.select { |key| public_send(key).blank? }
      raise ConfigurationError, I18n.t('atua.errors.missing_configuration', keys: missing.join(', ')) if missing.any?

      URI.parse(base_url).then { |uri| raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present? }
    rescue URI::InvalidURIError
      raise ConfigurationError, I18n.t('atua.errors.invalid_base_url')
    end
  end
end
