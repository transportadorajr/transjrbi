module Admin
  module Authentication
    extend ActiveSupport::Concern

    SESSION_TOKEN_KEY = :admin_session_token

    included do
      helper_method :current_admin_user
    end

    private

    def current_admin_session
      return @current_admin_session if defined?(@current_admin_session)

      @current_admin_session = Admin::Session.find_by(token: session[SESSION_TOKEN_KEY])
    end

    def current_admin_user
      current_admin_session&.user
    end

    def sign_in_admin_user(user)
      reset_session
      @current_admin_session = user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent)
      session[SESSION_TOKEN_KEY] = @current_admin_session.token
    end

    def sign_out_admin_user
      current_admin_session&.destroy
      session.delete(SESSION_TOKEN_KEY)
      @current_admin_session = nil
    end
  end
end
