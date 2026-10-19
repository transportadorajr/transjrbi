class FreightExpensesController < BaseController
  has_scope :by_transport_document_number, as: :number
  has_scope :by_kind, as: :kind
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :freight_expenses)

    freight_expenses = apply_scopes(current_tenant.freight_expenses)

    @freight_expenses = freight_expenses.preload(:transport_document, :commission_rule, :tonnage_rate, :insurance_rate)
      .joins(:transport_document)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, :kind_type, id: :desc)
      .page(params[:page])
    @customer_groups = current_tenant.customer_groups.where(id: current_tenant.commission_rules.select(:customer_group_id))
      .or(current_tenant.customer_groups.where(id: current_tenant.tonnage_rates.select(:customer_group_id))).order(:name)
    @amount_total = Money.from_cents(freight_expenses.sum(:amount_cents))
    @unmatched_documents = CommissionRule.unmatched_foreign_documents(current_tenant)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, :id)
    @missing_weight_documents = TonnageRate.missing_weight_documents(current_tenant)
    @outdated_tonnage_rates = TonnageRate.outdated(current_tenant)
    @current_insurance_rate = InsuranceRate.current(current_tenant)
  end

  def recalculate
    authorize!(:update, :commission_rules)

    FreightExpenses::CalculateJob.perform_later(current_tenant.id)

    redirect_to freight_expenses_path, notice: t('.success')
  end
end
