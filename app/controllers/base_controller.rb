class BaseController < ApplicationController
  include Sorting
  include ListingExport
  include MaintenanceHost

  before_action :require_signed_in_user
  before_action :require_password_change
  before_action :set_error_tracking_context
  before_action :set_current_tenant
  before_action :require_maintenance_host_feature

  private

  def current_ability
    @current_ability ||= Ability.new(current_user, resources: (Ability::MAINTENANCE_RESOURCES if maintenance_host?))
  end

  def current_tenant
    current_user.tenant
  end

  def require_signed_in_user
    redirect_to new_user_session_path unless user_signed_in?
  end

  def require_password_change
    redirect_to edit_password_change_path, status: :see_other if current_user.password_change_required?
  end

  def set_current_tenant
    Current.tenant = current_tenant
  end

  def set_error_tracking_context
    Sentry.set_user(id: current_user.id)
    Sentry.set_tags(tenant_id: current_user.tenant_id)
    Rails.error.set_context(user_id: current_user.id, tenant_id: current_user.tenant_id)
  end
end
