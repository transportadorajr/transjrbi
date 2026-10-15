module Atua
  class BackfillUnloadingExpensesCommand
    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      pending_expenses.find_each { |expense| fill_transport_document_number(expense) }

      LinkExpensesCommand.call(tenant)
    end

    private

    attr_reader :tenant

    def pending_expenses
      Expense.unloading.where(tenant_id: tenant.id, transport_document_code: nil, transport_document_number: nil)
        .where.not(document_number: nil)
    end

    def fill_transport_document_number(expense)
      number = Expense.unloading_transport_document_number(expense.history_code, expense.document_number)
      return unless number

      expense.update_columns(transport_document_number: number, updated_at: Time.current)
    end
  end
end
