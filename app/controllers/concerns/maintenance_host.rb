module MaintenanceHost
  extend ActiveSupport::Concern

  included do
    helper_method :maintenance_host?
  end

  private

  def maintenance_host?
    request.subdomain == Transjrbi::MAINTENANCE_SUBDOMAIN
  end

  def require_maintenance_host_feature
    return unless maintenance_host?

    raise ActionController::RoutingError, 'Not Found' unless MaintenanceOrder.enabled?(current_tenant)
  end
end
