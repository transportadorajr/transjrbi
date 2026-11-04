module DistanceAdjustments
  class ApplyPendingCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      adjustments.find_each.sum { |adjustment| ApplyCommand.call(adjustment) }
    end

    private

    attr_reader :tenant

    def adjustments
      unadjusted_numbers = tenant.atua_transport_documents.where(distance_adjusted_at: nil).select(:number)

      tenant.distance_adjustments.where(transport_document_number: unadjusted_numbers)
    end
  end
end
