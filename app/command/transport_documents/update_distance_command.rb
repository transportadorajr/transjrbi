module TransportDocuments
  class UpdateDistanceCommand
    class << self
      def call(transport_document, distance_km)
        new(transport_document, distance_km).call
      end
    end

    def initialize(transport_document, distance_km)
      @transport_document = transport_document
      @distance_km = distance_km
    end

    def call
      transport_document.transaction do
        transport_document.lock!
        next if unchanged?

        distance_km ? edit : restore
      end

      transport_document.reload
    end

    private

    attr_reader :transport_document, :distance_km

    def unchanged?
      return transport_document.distance_edited_at.nil? if distance_km.nil?

      transport_document.distance_edited_at.present? && transport_document.distance_km == distance_km
    end

    def edit
      edited_at = Time.current

      transport_document.update!(original_distance_km: transport_document.atua_distance_km, distance_km:, route_distance: nil,
                                 distance_adjusted_at: edited_at, distance_edited_at: edited_at)
    end

    def restore
      transport_document.update!(distance_km: transport_document.atua_distance_km, original_distance_km: nil, route_distance: nil,
                                 distance_adjusted_at: nil, distance_edited_at: nil)
      RouteDistances::ApplyCommand.call(transport_document.tenant)
    end
  end
end
