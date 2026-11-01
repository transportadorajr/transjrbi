class DriversController < BaseController
  TRANSPORT_DOCUMENTS_LIMIT = 10

  has_scope :by_driver_name, as: :name
  has_scope :by_driver_document, as: :document

  def index
    authorize!(:read, :drivers)

    @drivers = apply_sort(apply_scopes(current_tenant.atua_vehicles.drivers), :driver_name, :driver_code).page(params[:page])
  end

  def show
    authorize!(:read, :drivers)

    @driver = current_tenant.atua_vehicles.drivers.find_by!(driver_code: params.expect(:id))
    @vehicles = current_tenant.atua_vehicles.active.where(driver_code: @driver.driver_code).order(:plate)
    @transport_documents = current_tenant.atua_transport_documents.active.where(driver_code: @driver.driver_code)
      .order(Atua::TransportDocument.arel_table[:issued_at].desc.nulls_last, id: :desc)
      .limit(TRANSPORT_DOCUMENTS_LIMIT)
  end

  def destroy
    authorize!(:destroy, :drivers)

    Drivers::ExcludeCommand.call(current_tenant, current_tenant.atua_vehicles.drivers.find_by!(driver_code: params.expect(:id)))
    redirect_to drivers_path, notice: t('.success')
  end
end
