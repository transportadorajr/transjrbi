class MaintenanceHomeController < BaseController
  def index
    menu = Menu.find_and_wrap(:maintenance).lazy.filter_map { |item| item.landing(current_ability) }.first

    redirect_to menu.url if menu
  end
end
