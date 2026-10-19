require 'net/http'

module Tomtom
  class Client
    BASE_URL = 'https://api.tomtom.com'.freeze
    GEOCODE_PATH = '/search/2/geocode/%<query>s.json'.freeze
    ROUTE_PATH = '/routing/1/calculateRoute/%<origin>s:%<destination>s/json'.freeze
    COUNTRY = 'BR'.freeze
    LANGUAGE = 'pt-BR'.freeze
    MUNICIPALITY = 'Municipality'.freeze
    CANDIDATES = 5
    TRUCK = {
      travelMode: 'truck', vehicleCommercial: true, vehicleWeight: 45_000, vehicleNumberOfAxles: 6, routeType: 'fastest', traffic: false
    }.freeze
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30
    TOO_MANY_REQUESTS = 429
    NO_ROUTE = 400
    NETWORK_ERRORS = [
      Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
      Errno::ETIMEDOUT, EOFError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
    ].freeze

    def initialize(api_key: Tomtom.api_key)
      @api_key = api_key
    end

    def geocode(query, municipality: false)
      params = { countrySet: COUNTRY, language: LANGUAGE, limit: CANDIDATES }
      params[:entityTypeSet] = MUNICIPALITY if municipality

      Array(get(format(GEOCODE_PATH, query: ERB::Util.url_encode(query)), params)['results']).map { |result| Place.from_result(result) }
    end

    def route(origin, destination)
      path = format(ROUTE_PATH, origin: coordinates(origin), destination: coordinates(destination))
      summary = get(path, TRUCK, route: true).dig('routes', 0, 'summary')
      raise NoRouteError, I18n.t('tomtom.errors.no_route') unless summary

      Route.new(distance_meters: summary['lengthInMeters'], travel_time_seconds: summary['travelTimeInSeconds'])
    end

    def inspect
      "#<#{self.class.name} api_key=[FILTERED]>"
    end

    private

    attr_reader :api_key

    def get(path, params, route: false)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params.merge(key: api_key))

      http_request = Net::HTTP::Get.new(uri)
      response = Admin::HttpRequests::RecordCommand.call(:tomtom, http_request, secrets: [api_key]) do
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(http_request)
        end
      end

      JSON.parse(ensure_success(response, route:).body)
    rescue *NETWORK_ERRORS, JSON::ParserError => e
      raise RequestError, I18n.t('tomtom.errors.request_failed', path: URI(path).path, reason: e.message)
    end

    def ensure_success(response, route:)
      status = response.code.to_i
      return response if status == 200

      raise RateLimitError.new(I18n.t('tomtom.errors.rate_limited'), status:) if status == TOO_MANY_REQUESTS
      raise NoRouteError.new(I18n.t('tomtom.errors.no_route'), status:) if route && status == NO_ROUTE

      raise RequestError.new(I18n.t('tomtom.errors.unexpected_status', status:), status:)
    end

    def coordinates(location)
      "#{location.latitude},#{location.longitude}"
    end
  end
end
