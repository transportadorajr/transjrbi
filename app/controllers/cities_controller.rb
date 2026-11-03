class CitiesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_state, as: :state
  has_scope :by_macro_region, as: :macro_region_id

  before_action :set_city, only: %i[show edit update destroy]

  def index
    authorize!(:read, :cities)

    @cities = apply_sort(apply_scopes(current_tenant.cities.preload(:macro_region)), :state, :name, :id).page(params[:page])
    @macro_regions = current_tenant.macro_regions.order(:state, :name)
    @unassigned_origins = MacroRegion.unassigned_origins(current_tenant)
  end

  def show
    authorize!(:read, :cities)
  end

  def new
    authorize!(:create, :cities)

    @city_form = CityForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :cities)

    @city_form = CityForm.for_city(@city)
  end

  def create
    authorize!(:create, :cities)

    @city_form = CityForm.new(tenant: current_tenant, **city_params)

    if @city_form.save
      redirect_to city_path(@city_form.city), notice: t('.success')
    else
      flash.now[:alert] = @city_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :cities)

    @city_form = CityForm.for_city(@city)
    @city_form.assign_attributes(city_params)

    if @city_form.save
      redirect_to city_path(@city), notice: t('.success')
    else
      flash.now[:alert] = @city_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :cities)

    @city.destroy!
    MacroRegions::AssignCommand.call(current_tenant)

    redirect_to cities_path, notice: t('.success')
  end

  private

  def set_city
    @city = current_tenant.cities.find(params.expect(:id))
  end

  def city_params
    params.expect(city: %i[name state macro_region_id])
  end
end
