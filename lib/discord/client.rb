require 'net/http'

module Discord
  class Client
    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 3
    NETWORK_ERRORS = [
      Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      Errno::ETIMEDOUT, EOFError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    ].freeze

    def initialize(webhook_url: Discord.error_webhook_url)
      @webhook_url = webhook_url
    end

    def execute_webhook(payload)
      uri = URI(webhook_url)
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = payload.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      raise Error, I18n.t('discord.errors.unexpected_status', status: response.code) unless response.is_a?(Net::HTTPSuccess)

      response
    rescue *NETWORK_ERRORS => e
      raise Error, I18n.t('discord.errors.request_failed', reason: e.message)
    end

    def inspect
      "#<#{self.class.name} webhook_url=[FILTERED]>"
    end

    private

    attr_reader :webhook_url
  end
end
