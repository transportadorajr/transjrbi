module Dashboard
  class EmptyLegs
    Region = Data.define(:name, :legs_count, :total_km) do
      def average_km
        (total_km / legs_count).round(2) if legs_count.positive?
      end
    end

    def initialize(empty_legs)
      @empty_legs = empty_legs.unscope(:order, :select)
    end

    def legs_count
      totals.first
    end

    def total_km
      totals.last
    end

    def average_km
      (total_km / legs_count).round(2) if legs_count.positive?
    end

    def unmeasured_count
      @unmeasured_count ||= empty_legs.where.not(status_type: :calculated).count
    end

    def regions
      @regions ||= region_rows.map { |name, legs_count, total_km| Region.new(name: name || I18n.t('empty_legs.index.no_macro_region'), legs_count:, total_km:) }
        .sort_by { |region| [-region.total_km, region.name] }
    end

    private

    attr_reader :empty_legs

    def calculated
      empty_legs.calculated
    end

    def totals
      @totals ||= begin
        count, sum = calculated.pick(Arel.sql('COUNT(*)'), EmptyLeg.arel_table[:distance_km].sum)
        [count, sum || BigDecimal('0')]
      end
    end

    def region_rows
      legs = calculated.select(EmptyLeg.loading_macro_region_name.as('region_name'), EmptyLeg.arel_table[:distance_km])

      EmptyLeg.unscoped.from(legs, :legs).group(Arel.sql('legs.region_name'))
        .pluck(Arel.sql('legs.region_name'), Arel.sql('COUNT(*)'), Arel.sql('SUM(legs.distance_km)'))
    end
  end
end
