module ModuleHost
  extend ActiveSupport::Concern

  included do
    helper_method :host_module
  end

  private

  def host_module
    return @host_module if defined?(@host_module)

    @host_module = HostModule.find_by_subdomain(request.subdomain)
  end

  def require_host_module_feature
    return if host_module.nil? || host_module.enabled?(current_tenant)

    raise ActionController::RoutingError, 'Not Found'
  end

  def require_host_module_access
    return if host_module.nil? || can?(:read, host_module.key)

    sign_out(current_user)
    redirect_to new_user_session_path, alert: t("errors.messages.#{host_module.key}_access_denied")
  end
end
