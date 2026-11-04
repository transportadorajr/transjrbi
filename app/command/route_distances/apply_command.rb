module RouteDistances
  class ApplyCommand
    COLUMNS = %i[
      id taker_code origin_city origin_state destination_city destination_state route_distance_id distance_km distance_adjusted_at
    ].freeze

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
      @applied_at = Time.current
      @changes = Hash.new { |hash, key| hash[key] = [] }
    end

    def call
      candidates.pluck(*COLUMNS).each { |row| plan(COLUMNS.zip(row).to_h) }

      changes.sum { |(action, route), ids| ids.each_slice(1_000).sum { |batch| update(action, route, batch) } }
    end

    private

    attr_reader :tenant, :applied_at, :changes

    def routes
      @routes ||= RouteDistance.where(tenant:).index_by(&:route_key)
    end

    def candidates
      documents = tenant.atua_transport_documents

      documents.where(taker_code: routes.values.map(&:customer_code).uniq).or(documents.where.not(distance_adjusted_at: nil))
    end

    def plan(document)
      route = routes[RouteDistance.route_key(*document.values_at(:taker_code, :origin_city, :origin_state, :destination_city,
                                                                 :destination_state))]

      if route
        plan_route(document, route)
      elsif document[:distance_adjusted_at]
        changes[[:revert, nil]] << document[:id]
      end
    end

    def plan_route(document, route)
      if document[:distance_adjusted_at].nil?
        changes[[:adjust, route]] << document[:id]
      elsif document[:route_distance_id] != route.id || document[:distance_km] != route.distance_km
        changes[[:readjust, route]] << document[:id]
      end
    end

    def update(action, route, ids)
      documents = tenant.atua_transport_documents.where(id: ids)

      case action
      when :adjust
        documents.update_all(['original_distance_km = distance_km, distance_km = ?, route_distance_id = ?, distance_adjusted_at = ?, ' \
                              'updated_at = ?', route.distance_km, route.id, applied_at, applied_at])
      when :readjust
        documents.update_all(distance_km: route.distance_km, route_distance_id: route.id, distance_adjusted_at: applied_at, updated_at: applied_at)
      else
        documents.update_all(['distance_km = original_distance_km, original_distance_km = NULL, route_distance_id = NULL, ' \
                              'distance_adjusted_at = NULL, updated_at = ?', applied_at])
      end
    end
  end
end
