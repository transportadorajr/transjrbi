module Dashboard
  class FuelCost
    MONTHS = 12
    THIRD_PARTY_OWNERSHIPS = %w[Terceiro Agregado].freeze

    attr_reader :period

    def initialize(expenses, manifests:, until_on:)
      @expenses = expenses
      @manifests = manifests
      @period = until_on.months_ago(MONTHS).next_day..until_on
    end

    def cents_for(plate, distance, ownership)
      return 0 if THIRD_PARTY_OWNERSHIPS.include?(ownership)

      (rate_for(plate) * distance).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def rate_for(plate)
      rates.fetch(plate, BigDecimal('0'))
    end

    private

    attr_reader :expenses, :manifests

    def rates
      @rates ||= km_by_plate.select { |_plate, distance| distance.to_d.positive? }
        .to_h { |plate, distance| [plate, fuel_by_plate.fetch(plate, 0).to_d / distance.to_d] }
    end

    def fuel_by_plate
      @fuel_by_plate ||= expenses.active.fuel.by_spent_period(period).group(:plate).sum(:total_cents)
    end

    def km_by_plate
      manifests.trips
        .joins(empty_leg_join)
        .where(Arel.sql(Atua::Manifest.trip_on_sql).between(period))
        .group(:plate)
        .sum(Arel.sql(total_km_sql))
    end

    def empty_leg_join
      <<~SQL.squish
        LEFT JOIN empty_legs ON empty_legs.tenant_id = atua_manifests.tenant_id
          AND empty_legs.next_manifest_code = atua_manifests.code
          AND empty_legs.status_type = #{Atua::Manifest.connection.quote(Freight::CALCULATED_EMPTY_LEG)}
      SQL
    end

    def total_km_sql
      "COALESCE((#{Atua::Manifest.loaded_km_sql}), 0) + COALESCE(empty_legs.distance_km, 0)"
    end
  end
end
