module MaintenanceFeature
  extend ActiveSupport::Concern

  included do
    before_action :require_maintenance_feature
  end

  private

  def require_maintenance_feature
    raise ActionController::RoutingError, 'Not Found' unless MaintenanceOrder.enabled?(current_tenant)
  end
end
