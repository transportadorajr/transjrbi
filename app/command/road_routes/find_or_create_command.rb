module RoadRoutes
  class FindOrCreateCommand
    class << self
      def call(origin, destination, client: nil)
        new(origin, destination, client:).call
      end
    end

    def initialize(origin, destination, client: nil)
      @origin = origin.canonical
      @destination = destination.canonical
      @client = client
    end

    def call
      RoadRoute.find_by(origin:, destination:) || create_route
    end

    private

    attr_reader :origin, :destination

    def create_route
      route = client.route(origin, destination)

      RoadRoute.create!(origin:, destination:, distance_km: route.distance_km, travel_time_seconds: route.travel_time_seconds)
    rescue ActiveRecord::RecordNotUnique
      RoadRoute.find_by!(origin:, destination:)
    end

    def client
      @client ||= Tomtom::Client.new
    end
  end
end
