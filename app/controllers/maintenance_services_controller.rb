class MaintenanceServicesController < BaseController
  include MaintenanceCatalog

  private

  def catalog_scope
    current_tenant.maintenance_services
  end

  def catalog_form_class
    MaintenanceServiceForm
  end
end
