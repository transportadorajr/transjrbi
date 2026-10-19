module InsuranceRates
  class BackfillCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      return tenant.insurance_rates.order(:valid_from).first if tenant.insurance_rates.exists?

      rate = tenant.insurance_rates.create!(
        valid_from:,
        insurance_percentage: InsuranceRate::DEFAULT_INSURANCE_PERCENTAGE,
        iof_percentage: InsuranceRate::DEFAULT_IOF_PERCENTAGE,
      )
      FreightExpenses::CalculateInsuranceCommand.call(tenant)

      rate
    end

    private

    attr_reader :tenant

    def valid_from
      tenant.atua_transport_documents.minimum(:issued_at)&.in_time_zone&.to_date || Date.current
    end
  end
end
