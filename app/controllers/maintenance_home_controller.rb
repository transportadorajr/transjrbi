class MaintenanceHomeController < BaseController
  def index
    menu = Menu.find_and_wrap(:maintenance).find { |item| item.show?(current_ability) }

    redirect_to menu.url if menu
  end
end
