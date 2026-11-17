class MaintenancePartsController < BaseController
  include MaintenanceCatalog

  private

  def catalog_scope
    current_tenant.maintenance_parts
  end

  def catalog_form_class
    MaintenancePartForm
  end
end
