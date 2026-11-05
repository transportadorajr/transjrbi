class ManifestsController < BaseController
  include CustomerOptions

  has_scope :by_number, as: :number
  has_scope :by_plate, as: :plate
  has_scope :by_driver, as: :driver_code
  has_scope :by_product_group, as: :product_group_id
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_taker, as: :customer_code
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :manifests)

    load_filter_options
    manifests = Atua::Manifest.with_trip_totals(by_truck_group(apply_scopes(current_tenant.atua_manifests.active.not_canceled.with_transport_documents)))
      .preload(route_documents: { transport_document: { taker: :customer_group } })

    @manifests = apply_sort(manifests, Atua::Manifest.arel_table[:issued_on].desc.nulls_last, id: :desc, except: manifest_sort_exceptions)
      .page(params[:page])
  end

  def customer_options
    authorize!(:read, :manifests)

    load_customer_options
    render 'transport_documents/customer_options'
  end

  def show
    authorize!(:read, :manifests)

    @manifest = Atua::Manifest.with_trip_totals(current_tenant.atua_manifests.active.with_transport_documents)
      .preload(route_documents: :transport_document, empty_leg: %i[origin destination previous_manifest]).find(params.expect(:id))
    @documents = @manifest.documents.active.without_internal_taker.preload(:transport_document).order(:transport_document_number)
    load_trip_expenses
    load_net_freight
  end

  private

  def manifest_sort_exceptions
    can?(:read, :freight_expenses) ? [] : %w[net_per_km]
  end

  def load_filter_options
    @drivers = current_tenant.atua_transport_documents.drivers
    @truck_groups = current_tenant.truck_groups.activated.where(remaining_axles: false).order(:name)
    @product_groups = current_tenant.product_groups.groups.activated.order(:name)
    @customer_groups = current_tenant.customer_groups.activated.order(:name)
  end

  def by_truck_group(manifests)
    return manifests if params[:truck_group_id].blank?

    truck_group = @truck_groups.find_by(id: params[:truck_group_id])
    truck_group ? manifests.by_truck_group(truck_group, @truck_groups.flat_map(&:plates)) : manifests.none
  end

  def load_trip_expenses
    internal = can?(:read, :freight_expenses)
    atua = can?(:read, :expenses)
    return unless internal || atua

    @trip_expenses = TripExpenses.for(manifest_transport_documents, internal:, atua:)
  end

  def load_net_freight
    return unless can?(:read, :freight_expenses)

    @net_freight = NetFreight.for(manifest_transport_documents, missing_documents_freight: @manifest.missing_documents_freight)
    @net_cents_by_document = manifest_transport_documents.with_freight_totals.to_h { |document| [document.id, document.net_cents] }
  end

  def manifest_transport_documents
    @manifest.transport_documents.without_ce.merge(Atua::ManifestDocument.active)
  end
end
