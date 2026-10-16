module CustomerGroups
  class RecalculateCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      assigned = AssignCommand.call(tenant)

      assigned + tenant.customer_groups.with_terms.order(:id).sum { |group| RegroupCommand.call(group) }
    end

    private

    attr_reader :tenant
  end
end
