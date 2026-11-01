class ManifestsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_plate, as: :plate
  has_scope :by_period_start, as: :start_date
  has_scope :by_period_end, as: :end_date

  def index
    authorize!(:read, :manifests)

    manifests = apply_scopes(current_tenant.atua_manifests.active.not_canceled).with_freight_totals

    @manifests = apply_sort(manifests.preload(route_documents: :transport_document), Atua::Manifest.arel_table[:issued_on].desc.nulls_last, id: :desc)
      .page(params[:page])
  end

  def show
    authorize!(:read, :manifests)

    @manifest = current_tenant.atua_manifests.active.with_freight_totals
      .preload(route_documents: :transport_document, empty_leg: %i[origin destination previous_manifest]).find(params.expect(:id))
    @documents = @manifest.documents.active.without_internal_taker.preload(:transport_document).order(:transport_document_number)
    load_trip_expenses
    @net_freight = NetFreight.for(manifest_transport_documents) if can?(:read, :freight_expenses)
  end

  private

  def load_trip_expenses
    internal = can?(:read, :freight_expenses)
    atua = can?(:read, :expenses)
    return unless internal || atua

    @trip_expenses = TripExpenses.for(manifest_transport_documents, internal:, atua:)
  end

  def manifest_transport_documents
    @manifest.transport_documents.merge(Atua::ManifestDocument.active)
  end
end
