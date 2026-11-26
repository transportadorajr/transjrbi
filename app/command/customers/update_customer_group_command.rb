module Customers
  class UpdateCustomerGroupCommand
    class << self
      def call(customer, customer_group)
        new(customer, customer_group).call
      end
    end

    def initialize(customer, customer_group)
      @customer = customer
      @customer_group = customer_group
    end

    def call
      changed = customer.with_lock do
        next false if customer.customer_group_id == customer_group.id

        customer.update!(customer_group:, customer_group_edited_at: Time.current)
      end

      FreightExpenses::CalculateJob.perform_later(customer.tenant_id) if changed

      customer
    end

    private

    attr_reader :customer, :customer_group
  end
end
