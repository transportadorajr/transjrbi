class TransportDocumentsController < BaseController
  include CustomerOptions

  has_scope :by_number, as: :number
  has_scope :by_document_kind, as: :document_kind
  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_taker, as: :customer_code
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :transport_documents)

    transport_documents = apply_scopes(current_tenant.atua_transport_documents.active.freights.not_canceled)
    @transport_documents = listing_page(sorted_transport_documents(transport_documents))
    @valid_count = transport_documents.count
    @groups = Dashboard::ListingGroups.for_transport_documents(transport_documents, dimension: params[:dimension], net: can?(:read, :freight_expenses))
    @drivers = current_tenant.atua_transport_documents.drivers
    @customer_groups = current_tenant.customer_groups.activated.order(:name)

    respond_with_listing(orientation: :landscape)
  end

  def customer_options
    authorize!(:read, :transport_documents)

    load_customer_options
  end

  def show
    authorize!(:read, :transport_documents)

    @transport_document = current_tenant.atua_transport_documents.active.find(params.expect(:id))
    @manifests = @transport_document.linked_manifests.active.order(:issued_on, :number)
    @empty_legs = @transport_document.empty_legs.preload(:origin, :destination).order(:next_manifest_code)
    load_expenses if can?(:read, :expenses)
    load_net_freight if can?(:read, :freight_expenses)
  end

  def resync
    authorize!(:update, :transport_documents)

    transport_document = current_tenant.atua_transport_documents.active.find(params.expect(:id))
    issued_on = transport_document.issued_at&.to_date

    if Atua.enabled?(current_tenant) && issued_on
      Atua::ImportReportJob.perform_later(current_tenant.id, 'transport_documents', issued_on, issued_on)
      redirect_to transport_document_path(transport_document), notice: t('.success', date: l(issued_on))
    else
      redirect_to transport_document_path(transport_document), alert: t('.unavailable')
    end
  end

  private

  def sorted_transport_documents(transport_documents)
    apply_sort(transport_documents.with_freight_totals,
               Atua::TransportDocument.arel_table[:posted_on].desc.nulls_last,
               Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last,
               id: :desc, except: hidden_sort_columns)
      .preload(taker: :customer_group)
  end

  def hidden_sort_columns
    can?(:read, :freight_expenses) ? [] : %w[net]
  end

  def load_net_freight
    return if @transport_document.canceled? || @transport_document.vehicle_sale?

    @net_freight = NetFreight.for(current_tenant.atua_transport_documents.where(id: @transport_document.id))
    freight_expenses = @transport_document.freight_expenses

    @freight_expenses = freight_expenses.preload(:commission_rule, :tonnage_rate, :insurance_rate).order(:kind_type, :id)
    @freight_expenses_total = Money.from_cents(freight_expenses.sum(:amount_cents))
  end

  def load_expenses
    expenses = @transport_document.expenses.active

    @expenses = expenses.order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc)
    @complements = @transport_document.complement_credits.order(:issued_at, :id)
    @expenses_total = Money.from_cents(expenses.sum(:total_cents) - @complements.sum(:freight_cents)) + @transport_document.complement_transfer
  end
end
