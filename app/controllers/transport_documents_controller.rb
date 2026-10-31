class TransportDocumentsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_taker, as: :customer_code
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date
  has_scope :by_situation, as: :status

  def index
    authorize!(:read, :transport_documents)

    transport_documents = current_tenant.atua_transport_documents.active
    counted_transport_documents = apply_scopes(transport_documents, params.except(:status))

    @transport_documents = apply_sort(apply_scopes(transport_documents).with_freight_totals,
                                      Atua::TransportDocument.arel_table[:posted_on].desc.nulls_last,
                                      Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last,
                                      id: :desc, except: hidden_sort_columns)
      .page(params[:page])
    @total_count = counted_transport_documents.count
    @valid_count = counted_transport_documents.not_canceled.count
    @canceled_count = counted_transport_documents.canceled.count
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.order(:name)
  end

  def customer_options
    authorize!(:read, :transport_documents)

    customers = current_tenant.atua_customers.active.order(:name, :id)
    customers = customers.by_customer_group(params[:customer_group_id]) if params[:customer_group_id].present?

    @customers = customers.select(:code, :name, :document)
    @selected_customer_code = params[:customer_code] if params[:customer_code].present? && customers.exists?(code: params[:customer_code])
  end

  def show
    authorize!(:read, :transport_documents)

    @transport_document = current_tenant.atua_transport_documents.active.find(params.expect(:id))
    @manifests = @transport_document.manifests.active.order(:issued_on, :number)
    @empty_legs = @transport_document.empty_legs.preload(:origin, :destination).order(:next_manifest_code)
    load_expenses if can?(:read, :expenses)
    load_net_freight if can?(:read, :freight_expenses)
  end

  private

  def hidden_sort_columns
    can?(:read, :freight_expenses) ? [] : %w[net]
  end

  def load_net_freight
    return if @transport_document.canceled?

    @net_freight = NetFreight.for(current_tenant.atua_transport_documents.where(id: @transport_document.id))
    freight_expenses = @transport_document.freight_expenses

    @freight_expenses = freight_expenses.preload(:commission_rule, :tonnage_rate, :insurance_rate).order(:kind_type, :id)
    @freight_expenses_total = Money.from_cents(freight_expenses.sum(:amount_cents))
  end

  def load_expenses
    expenses = @transport_document.expenses.active

    @expenses = expenses.order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
    @expenses_total = Money.from_cents(expenses.sum(:total_cents))
  end
end
