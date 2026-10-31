module Admin
  class BaseController < ApplicationController
    include Admin::Authentication
    include Sorting

    layout 'admin'

    before_action :authenticate_admin_user!
    before_action :set_current_admin_user

    private

    def authenticate_admin_user!
      admin_session = current_admin_session

      return redirect_to(admin_login_path, alert: t('admin.sessions.unauthenticated')) if admin_session.blank?

      if admin_session.expired?
        sign_out_admin_user

        return redirect_to(admin_login_path, alert: t('admin.sessions.expired'))
      end

      admin_session.renew
    end

    def set_current_admin_user
      Current.admin_user = current_admin_user
    end
  end
end
