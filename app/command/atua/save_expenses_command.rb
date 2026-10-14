module Atua
  class SaveExpensesCommand < SaveReportCommand
    MODEL = Expense
    MAPPER = MapExpensesCommand
    PREVIOUS_ATTRIBUTES = %i[attachment_at].freeze
  end
end
