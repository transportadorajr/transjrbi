module EmptyLegs
  class CalculateCommand
    class << self
      def call(manifest, client: nil)
        new(manifest, client:).call
      end
    end

    def initialize(manifest, client: nil)
      @manifest = manifest
      @client = client
    end

    def call
      previous_trip = manifest.trip? && manifest.previous_trip
      return remove_leg unless previous_trip

      leg = EmptyLeg.find_or_initialize_by(tenant_id: manifest.tenant_id, next_manifest_code: manifest.code)
      EmptyLeg.transaction do
        leg.update!(plate: manifest.plate, previous_manifest_code: previous_trip.code, calculated_at: Time.current, **measure(previous_trip))
        link_transport_documents(leg)
      end
      leg
    end

    private

    attr_reader :manifest, :client

    def remove_leg
      EmptyLeg.where(tenant_id: manifest.tenant_id, next_manifest_code: manifest.code).delete_all
      nil
    end

    def measure(previous_trip)
      origin = locate(previous_trip.ordered_documents.last, :destination)
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
      codes = documents.filter_map { |document| document.transport_document&.code }.uniq
      leg.empty_leg_transport_documents.where.not(transport_document_code: codes).delete_all

      rows = codes.map { |transport_document_code| { empty_leg_id: leg.id, tenant_id: leg.tenant_id, transport_document_code: } }
      EmptyLegTransportDocument.insert_all(rows, unique_by: %i[empty_leg_id transport_document_code]) if rows.any?
    end

    def documents
      @documents ||= manifest.ordered_documents
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
      source = [document.transport_document, document].compact.find { |record| record.public_send(:"#{side}_city").present? } || document

      [source.public_send(:"#{side}_city"), source.public_send(:"#{side}_state")]
    end

    def street_of(document, side, city, state)
      customer = document.transport_document&.public_send(side == :origin ? :sender : :recipient)
      return unless customer
      return unless Location.normalize(customer.city) == Location.normalize(city) && Location.normalize(customer.state) == Location.normalize(state)

      customer.street
    end
  end
end
