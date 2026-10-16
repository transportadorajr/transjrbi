class ManifestsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_plate, as: :plate
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date
  has_scope :by_situation, as: :status

  def index
    authorize!(:read, :manifests)

    manifests = current_tenant.atua_manifests.active
    counted_manifests = apply_scopes(manifests, params.except(:status))

    @manifests = apply_scopes(manifests)
      .order(Atua::Manifest.arel_table[:issued_on].desc.nulls_last, id: :desc)
      .page(params[:page])
    @total_count = counted_manifests.count
    @valid_count = counted_manifests.not_canceled.count
    @canceled_count = counted_manifests.canceled.count
  end

  def show
    authorize!(:read, :manifests)

    @manifest = current_tenant.atua_manifests.active.preload(empty_leg: %i[origin destination previous_manifest]).find(params.expect(:id))
    @documents = @manifest.documents.active.preload(:transport_document).order(:transport_document_number)
    load_expenses if can?(:read, :expenses)
    load_net_freight if can?(:read, :freight_expenses)
  end

  private

  def load_net_freight
    transport_documents = @manifest.transport_documents.merge(Atua::ManifestDocument.active)
    commissions = current_tenant.freight_expenses.commission
      .where(transport_document_id: transport_documents.active.not_canceled.select(:id))

    @net_freight = NetFreight.for(transport_documents)
    @commissions = commissions.preload(:transport_document, :commission_rule)
      .joins(:transport_document).order(Atua::TransportDocument.arel_table[:number], :id)
    @commissions_total = Money.from_cents(commissions.sum(:amount_cents))
  end

  def load_expenses
    expenses = current_tenant.atua_expenses.active.by_manifest(@manifest)

    @expenses = expenses.preload(:cost_object).order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
    @expenses_total = Money.from_cents(expenses.sum(:total_cents))
  end
end
