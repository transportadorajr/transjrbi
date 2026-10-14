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

    @manifest = current_tenant.atua_manifests.active.find(params.expect(:id))
    @documents = @manifest.documents.active.preload(:transport_document).order(:transport_document_number)
  end
end
