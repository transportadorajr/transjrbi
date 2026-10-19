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
      return tenant.insurance_rate if tenant.insurance_rate

      rate = tenant.create_insurance_rate!(
        insurance_percentage: InsuranceRate::DEFAULT_INSURANCE_PERCENTAGE,
        iof_percentage: InsuranceRate::DEFAULT_IOF_PERCENTAGE,
      )
      FreightExpenses::CalculateInsuranceCommand.call(tenant)

      rate
    end

    private

    attr_reader :tenant
  end
end
