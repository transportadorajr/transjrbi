class ExportPlantsController < BaseController
  include Activation

  has_scope :by_name, as: :name
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_status, as: :status

  before_action :require_export_summary
  before_action :set_export_plant, only: %i[show edit update destroy activate deactivate]

  def index
    authorize!(:read, :export_plants)

    export_plants = current_tenant.export_plants
    counted_export_plants = apply_scopes(export_plants, params.except(:status))

    @export_plants = listing_page(apply_sort(apply_scopes(export_plants).preload(:customer_group).joins(:customer_group),
                                             CustomerGroup.arel_table[:name], :name, :id))
    @customer_groups = current_tenant.customer_groups.where(id: export_plants.select(:customer_group_id)).order(:name)
    @total_count = counted_export_plants.count
    @active_count = counted_export_plants.activated.count
    @deactivated_count = counted_export_plants.not_activated.count

    respond_with_listing(orientation: :landscape, xlsx: @export_plants)
  end

  def show
    authorize!(:read, :export_plants)
  end

  def new
    authorize!(:create, :export_plants)

    @export_plant_form = ExportPlantForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :export_plants)

    @export_plant_form = ExportPlantForm.for_export_plant(@export_plant)
  end

  def create
    authorize!(:create, :export_plants)

    @export_plant_form = ExportPlantForm.new(tenant: current_tenant, **export_plant_params)

    if @export_plant_form.save
      redirect_to export_plant_path(@export_plant_form.export_plant), notice: t('.success')
    else
      flash.now[:alert] = @export_plant_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :export_plants)

    @export_plant_form = ExportPlantForm.for_export_plant(@export_plant)
    @export_plant_form.assign_attributes(export_plant_params)

    if @export_plant_form.save
      redirect_to export_plant_path(@export_plant), notice: t('.success')
    else
      flash.now[:alert] = @export_plant_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :export_plants)

    if @export_plant.destroy
      redirect_to export_plants_path, notice: t('.success')
    else
      redirect_to export_plants_path, alert: @export_plant.errors.full_messages.to_sentence
    end
  end

  private

  def require_export_summary
    raise ActionController::RoutingError, 'Not Found' unless ExportPlant.enabled?(current_tenant)
  end

  def activation_form
    ExportPlantForm.for_export_plant(@export_plant)
  end

  def set_export_plant
    @export_plant = current_tenant.export_plants.find(params.expect(:id))
  end

  def export_plant_params
    params.expect(export_plant: %i[customer_group_id name cities active])
  end
end
