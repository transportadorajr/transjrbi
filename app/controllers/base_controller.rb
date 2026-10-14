class BaseController < ApplicationController
  before_action :require_signed_in_user

  private

  def current_tenant
    current_user.tenant
  end

  def require_signed_in_user
    redirect_to new_user_session_path unless user_signed_in?
  end
end
