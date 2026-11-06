class RouteDistancesController < BaseController
  has_scope :by_customer, as: :customer_code
  has_scope :by_origin, as: :origin
  has_scope :by_destination, as: :destination

  before_action :set_route_distance, only: %i[edit update destroy]
  before_action :load_customers, only: %i[index new edit create update]

  def index
    authorize!(:read, :route_distances)

    route_distances = current_tenant.route_distances.with_documents_count.preload(:customer)
    @route_distances = listing_page(apply_sort(apply_scopes(route_distances), RouteDistance.sort_text(RouteDistance.customer_name).asc,
                                               :origin_city, :destination_city, :id))
    @route_distance_import_form = RouteDistanceImportForm.new(tenant: current_tenant)

    respond_with_listing
  end

  def new
    authorize!(:create, :route_distances)

    @route_distance_form = RouteDistanceForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :route_distances)

    @route_distance_form = RouteDistanceForm.for_route_distance(@route_distance)
  end

  def create
    authorize!(:create, :route_distances)

    @route_distance_form = RouteDistanceForm.new(tenant: current_tenant, **route_distance_params)

    if @route_distance_form.save
      redirect_to route_distances_path, notice: t('route_distances.saved', count: @route_distance_form.documents_count)
    else
      flash.now[:alert] = @route_distance_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :route_distances)

    @route_distance_form = RouteDistanceForm.for_route_distance(@route_distance)
    @route_distance_form.assign_attributes(route_distance_params)

    if @route_distance_form.save
      redirect_to route_distances_path, notice: t('route_distances.saved', count: @route_distance_form.documents_count)
    else
      flash.now[:alert] = @route_distance_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :route_distances)

    RouteDistances::DestroyCommand.call(@route_distance)
    redirect_to route_distances_path, notice: t('.success')
  end

  def import
    authorize!(:create, :route_distances)

    form = RouteDistanceImportForm.new(tenant: current_tenant, file: params.dig(:route_distance_import, :file))

    if form.save
      redirect_to route_distances_path, notice: import_notice(form.result), alert: form.result.errors.join(' ').presence
    else
      redirect_to route_distances_path, alert: form.errors.full_messages.to_sentence
    end
  end

  private

  def set_route_distance
    @route_distance = current_tenant.route_distances.find(params.expect(:id))
  end

  def load_customers
    @customers = current_tenant.atua_customers.where(code: current_tenant.atua_transport_documents.select(:taker_code))
      .order(:name, :code)
  end

  def route_distance_params
    params.expect(route_distance: %i[customer_code origin_city origin_state destination_city destination_state distance_km])
  end

  def import_notice(result)
    t('.success', created: result.created, updated: result.updated, documents: result.documents)
  end
end
