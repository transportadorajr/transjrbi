module Atua
  class SaveExpensesCommand < SaveReportCommand
    MODEL = Expense
    MAPPER = MapExpensesCommand
    PREVIOUS_ATTRIBUTES = %i[attachment_at].freeze

    def call
      super.tap { DiscardExcludedPlatesCommand.call(tenant) }
    end
  end
end
