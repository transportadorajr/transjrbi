module Dashboard
  class FleetProductivity
    RANKING_LIMIT = 15

    Ranking = Data.define(:key, :label, :legs_count, :total_km) do
      def average_km
        (total_km / legs_count).round(2) if legs_count.positive?
      end
    end

    def initialize(empty_legs, macro_regions:)
      @empty_legs = empty_legs
      @macro_regions = macro_regions
    end

    delegate :empty?, to: :measured

    def legs_count
      measured.size
    end

    def total_km
      @total_km ||= measured.sum(BigDecimal('0'), &:distance_km).round(2)
    end

    def average_km
      (total_km / legs_count).round(2) if legs_count.positive?
    end

    def unmeasured_count
      @unmeasured_count ||= empty_legs.where.not(status_type: :calculated).count
    end

    def routes
      @routes ||= rank(measured.group_by { |leg| route_key(leg) }) { |key| route_label(*key) }
    end

    def unloading_regions
      @unloading_regions ||= rank(measured.group_by { |leg| unloading_region(leg) }) do |region|
        region&.name || I18n.t('dashboards.fleet_productivity.no_macro_region')
      end
    end

    def routes_chart_data
      [{ name: I18n.t('dashboards.fleet_productivity.empty_km'), data: routes.first(RANKING_LIMIT).to_h { |route| [route.label, route.total_km.to_f] } }]
    end

    private

    attr_reader :empty_legs, :macro_regions

    def measured
      @measured ||= empty_legs.calculated.where.not(origin_id: nil).where.not(destination_id: nil).preload(:origin, :destination).to_a
    end

    def rank(groups)
      groups.map { |key, legs| build_ranking(key, yield(key), legs) }.sort_by { |ranking| [-ranking.total_km, ranking.label] }
    end

    def build_ranking(key, label, legs)
      Ranking.new(key: ranking_key(key), label:, legs_count: legs.size, total_km: legs.sum(BigDecimal('0'), &:distance_km).round(2))
    end

    def ranking_key(key)
      key.is_a?(MacroRegion) ? key.id.to_s : Array(key).join('|')
    end

    def route_key(leg)
      [leg.origin.city, leg.origin.state, leg.destination.city, leg.destination.state].map { |part| Location.normalize(part) }
    end

    def route_label(origin_city, origin_state, destination_city, destination_state)
      I18n.t('dashboards.fleet_productivity.route', origin: city_label(origin_city, origin_state), destination: city_label(destination_city, destination_state))
    end

    def city_label(city, state)
      I18n.t('dashboards.fleet_productivity.city', city:, state:)
    end

    def unloading_region(leg)
      MacroRegion.for_origin(macro_regions, leg.origin.city, leg.origin.state)
    end
  end
end
