module MacroRegions
  class AssignCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      origins.group_by { |city, state| MacroRegion.for_origin(regions, city, state)&.id }.sum do |region_id, grouped|
        documents_from(grouped).where(table[:origin_macro_region_id].is_distinct_from(region_id))
          .update_all(origin_macro_region_id: region_id, updated_at: Time.current)
      end
    end

    private

    attr_reader :tenant

    def origins
      tenant.atua_transport_documents.distinct.pluck(:origin_city, :origin_state)
    end

    def regions
      @regions ||= tenant.macro_regions.reload.to_a
    end

    def documents_from(origins)
      origins.group_by(&:last).map { |state, pairs| tenant.atua_transport_documents.where(origin_state: state, origin_city: pairs.map(&:first)) }
        .reduce(:or)
    end

    def table
      Atua::TransportDocument.arel_table
    end
  end
end
