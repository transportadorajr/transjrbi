class BaseController < ApplicationController
  before_action :require_signed_in_user
  before_action :require_password_change

  private

  def current_tenant
    current_user.tenant
  end

  def require_signed_in_user
    redirect_to new_user_session_path unless user_signed_in?
  end

  def require_password_change
    redirect_to edit_password_change_path, status: :see_other if current_user.password_change_required?
  end
end
