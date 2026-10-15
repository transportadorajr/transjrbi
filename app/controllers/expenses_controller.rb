class ExpensesController < BaseController
  has_scope :by_plate, as: :plate
  has_scope :by_history, as: :history
  has_scope :by_allocation, as: :allocation
  has_scope :by_payee_name, as: :payee
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :expenses)

    expenses = current_tenant.atua_expenses.active

    @expenses = apply_scopes(expenses)
      .order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
      .page(params[:page])
    @histories = expenses.where.not(history_code: nil).distinct.order(:history_name, :history_code).pluck(:history_name, :history_code)
  end

  def show
    authorize!(:read, :expenses)

    @expense = current_tenant.atua_expenses.active.preload(:cost_object).find(params.expect(:id))
  end
end
