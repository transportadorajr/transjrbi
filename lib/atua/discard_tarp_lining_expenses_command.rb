module Atua
  class DiscardTarpLiningExpensesCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      group = FreightExpenses::CalculateTarpLiningCommand.customer_group(tenant)
      return 0 unless group

      now = Time.current
      expenses(group).update_all(removed_from_atua_at: now, updated_at: now)
    end

    private

    attr_reader :tenant

    def expenses(group)
      tenant.atua_expenses.active
        .where(total_cents: FreightExpenses::CalculateTarpLiningCommand::RATE_CENTS)
        .where(payee_code: tenant.atua_customers.where(customer_group_id: group.id).select(:code))
    end
  end
end
