class FreightExpensesController < BaseController
  has_scope :by_transport_document_number, as: :number
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :freight_expenses)

    freight_expenses = apply_scopes(current_tenant.freight_expenses)

    @freight_expenses = freight_expenses.preload(:transport_document, commission_rule: :customer_group)
      .joins(:transport_document)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, id: :desc)
      .page(params[:page])
    @customer_groups = current_tenant.customer_groups.where(id: current_tenant.commission_rules.select(:customer_group_id)).order(:name)
    @base_total = Money.from_cents(freight_expenses.sum(:base_cents))
    @amount_total = Money.from_cents(freight_expenses.sum(:amount_cents))
    @unmatched_documents = CommissionRule.unmatched_foreign_documents(current_tenant)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, :id)
  end

  def recalculate
    authorize!(:update, :commission_rules)

    FreightExpenses::CalculateCommissionsJob.perform_later(current_tenant.id)

    redirect_to freight_expenses_path, notice: t('.success')
  end
end
