module Atua
  class SaveExpensesCommand < SaveReportCommand
    MODEL = Expense
    MAPPER = MapExpensesCommand
    PREVIOUS_ATTRIBUTES = %i[attachment_at].freeze

    def call
      super.tap do
        DiscardExcludedPlatesCommand.call(tenant)
        DiscardTarpLiningExpensesCommand.call(tenant)
      end
    end
  end
end
