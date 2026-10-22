class MacroRegionsController < BaseController
  has_scope :by_name, as: :name

  before_action :set_macro_region, only: %i[show edit update destroy]

  def index
    authorize!(:read, :macro_regions)

    @macro_regions = apply_scopes(current_tenant.macro_regions).order(:state, :name, :id).page(params[:page])
  end

  def show
    authorize!(:read, :macro_regions)

    @transport_documents_count = @macro_region.transport_documents.count
  end

  def new
    authorize!(:create, :macro_regions)

    @macro_region_form = MacroRegionForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :macro_regions)

    @macro_region_form = MacroRegionForm.for_macro_region(@macro_region)
  end

  def create
    authorize!(:create, :macro_regions)

    @macro_region_form = MacroRegionForm.new(tenant: current_tenant, **macro_region_params)

    if @macro_region_form.save
      redirect_to macro_region_path(@macro_region_form.macro_region), notice: t('.success')
    else
      flash.now[:alert] = @macro_region_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :macro_regions)

    @macro_region_form = MacroRegionForm.for_macro_region(@macro_region)
    @macro_region_form.assign_attributes(macro_region_params)

    if @macro_region_form.save
      redirect_to macro_region_path(@macro_region), notice: t('.success')
    else
      flash.now[:alert] = @macro_region_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :macro_regions)

    @macro_region.destroy!
    MacroRegions::AssignCommand.call(current_tenant)

    redirect_to macro_regions_path, notice: t('.success')
  end

  private

  def set_macro_region
    @macro_region = current_tenant.macro_regions.find(params.expect(:id))
  end

  def macro_region_params
    params.expect(macro_region: %i[name state cities remaining_state])
  end
end
