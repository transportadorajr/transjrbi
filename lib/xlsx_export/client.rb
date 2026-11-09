require 'net/http'

module XlsxExport
  class Client
    WORKBOOKS_PATH = '/v1/workbooks'.freeze
    JSON_CONTENT_TYPE = 'application/json'.freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 120
    MESSAGE_LENGTH = 300
    NETWORK_ERRORS = [
      Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      Errno::ETIMEDOUT, Errno::EPIPE, EOFError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    ].freeze

    def initialize(url: XlsxExport.url, token: XlsxExport.token)
      @url = url
      @token = token
    end

    def workbook(sheets)
      response = post(WORKBOOKS_PATH, { sheets: }.to_json)
      return response.body.b if response.is_a?(Net::HTTPSuccess)

      raise RequestError, I18n.t('xlsx_export.errors.status', status: response.code, message: error_message(response))
    rescue *NETWORK_ERRORS => e
      raise RequestError, I18n.t('xlsx_export.errors.unavailable', reason: e.message)
    end

    def inspect
      "#<#{self.class.name} url=#{url} token=[FILTERED]>"
    end

    private

    attr_reader :url, :token

    def post(path, body)
      uri = URI.join(url, path)
      request = Net::HTTP::Post.new(uri, 'Content-Type' => JSON_CONTENT_TYPE)
      request['Authorization'] = "Bearer #{token}" if token.present?
      request.body = body

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
    end

    def error_message(response)
      JSON.parse(response.body.to_s).fetch('error', '').to_s.truncate(MESSAGE_LENGTH)
    rescue JSON::ParserError
      response.body.to_s.truncate(MESSAGE_LENGTH)
    end
  end
end
