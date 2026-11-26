module EmptyLegs
  class CalculateCommand
    class << self
      def call(trip, client: nil)
        new(trip, client:).call
      end
    end

    def initialize(trip, client: nil)
      @trip = trip
      @client = client
    end

    def call
      previous_trip = trip_valid? && trip.previous_trip
      return remove_leg unless previous_trip

      leg = EmptyLeg.find_or_initialize_by(tenant_id: trip.tenant_id, **leg_key(trip, :next))
      EmptyLeg.transaction do
        leg.update!(plate: trip.plate, **leg_key(previous_trip, :previous), calculated_at: Time.current, **measure(previous_trip))
        link_transport_documents(leg)
      end
      leg
    end

    private

    attr_reader :trip, :client

    def trip_valid?
      manifest? ? trip.trip? : Atua::TransportDocument.ce_trips.exists?(id: trip.id)
    end

    def manifest?
      trip.is_a?(Atua::Manifest)
    end

    def leg_key(leg_trip, side)
      kind = leg_trip.is_a?(Atua::Manifest) ? :manifest : :transport_document
      codes = %i[manifest transport_document].to_h { |key| [:"#{side}_#{key}_code", key == kind ? leg_trip.code : nil] }

      side == :next ? codes.compact : codes
    end

    def remove_leg
      EmptyLeg.where(tenant_id: trip.tenant_id, **leg_key(trip, :next)).delete_all
      nil
    end

    def measure(previous_trip)
      origin = locate(previous_trip.leg_documents.last, :destination)
      destination = locate(documents.first, :origin)
      return unmeasured(:unlocated, origin, destination) unless origin && destination

      route = road_route(origin, destination)
      {
        origin:, destination:, road_route: route, distance_km: route&.distance_km || 0, status_type: :calculated,
        precision_type: [origin, destination].all?(&:precision_address?) ? :address : :city
      }
    rescue Tomtom::NoRouteError
      unmeasured(:unrouted, origin, destination)
    end

    def link_transport_documents(leg)
      codes = documents.filter_map { |document| transport_document_of(document)&.code }.uniq
      leg.empty_leg_transport_documents.where.not(transport_document_code: codes).delete_all

      rows = codes.map { |transport_document_code| { empty_leg_id: leg.id, tenant_id: leg.tenant_id, transport_document_code: } }
      EmptyLegTransportDocument.insert_all(rows, unique_by: %i[empty_leg_id transport_document_code]) if rows.any?
    end

    def documents
      @documents ||= trip.leg_documents
    end

    def transport_document_of(document)
      document.is_a?(Atua::TransportDocument) ? document : document.transport_document
    end

    def unmeasured(status_type, origin, destination)
      { origin:, destination:, road_route: nil, distance_km: nil, precision_type: nil, status_type: }
    end

    def road_route(origin, destination)
      return if origin.same_place?(destination)

      RoadRoutes::FindOrCreateCommand.call(origin, destination, client:)
    end

    def locate(document, side)
      return unless document

      city, state = place_of(document, side)
      Locations::FindOrCreateCommand.call(street: street_of(document, side, city, state), city:, state:, client:)
    end

    def place_of(document, side)
      source = [transport_document_of(document), document].compact.find { |record| record.public_send(:"#{side}_city").present? } || document

      [source.public_send(:"#{side}_city"), source.public_send(:"#{side}_state")]
    end

    def street_of(document, side, city, state)
      customer = transport_document_of(document)&.public_send(side == :origin ? :sender : :recipient)
      return unless customer
      return unless Location.normalize(customer.city) == Location.normalize(city) && Location.normalize(customer.state) == Location.normalize(state)

      customer.street
    end
  end
end
