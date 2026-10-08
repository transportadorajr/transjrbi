class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  layout :layout_by_resource

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_back_or_to(root_path, alert: t('errors.messages.access_denied'))
  end

  private

  def layout_by_resource
    devise_controller? && controller_name == 'sessions' ? 'bare' : 'application'
  end
end
