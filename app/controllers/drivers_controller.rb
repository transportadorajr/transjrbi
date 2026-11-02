class DriversController < BaseController
  TRANSPORT_DOCUMENTS_LIMIT = 10

  has_scope :by_driver_name, as: :name
  has_scope :by_driver_document, as: :document

  before_action :set_driver, only: %i[show edit update destroy]

  def index
    authorize!(:read, :drivers)

    @drivers = apply_sort(apply_scopes(current_tenant.atua_vehicles.drivers), :driver_name, :driver_code).page(params[:page])
  end

  def show
    authorize!(:read, :drivers)

    @vehicles = current_tenant.atua_vehicles.active.where(driver_code: @driver.driver_code).order(:plate)
    @transport_documents = current_tenant.atua_transport_documents.active.freights.where(driver_code: @driver.driver_code)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, id: :desc)
      .limit(TRANSPORT_DOCUMENTS_LIMIT)
  end

  def edit
    authorize!(:update, :drivers)

    @driver_form = DriverForm.for_driver(current_tenant, @driver)
  end

  def update
    authorize!(:update, :drivers)

    @driver_form = DriverForm.for_driver(current_tenant, @driver)
    @driver_form.assign_attributes(driver_params)

    if @driver_form.save
      redirect_to driver_path(@driver.driver_code), notice: t('.success')
    else
      flash.now[:alert] = @driver_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :drivers)

    Drivers::ExcludeCommand.call(current_tenant, @driver)
    redirect_to drivers_path, notice: t('.success')
  end

  private

  def set_driver
    @driver = current_tenant.atua_vehicles.drivers.find_by!(driver_code: params.expect(:id))
  end

  def driver_params
    params.expect(driver: %i[display_name])
  end
end
