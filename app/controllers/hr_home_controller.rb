class HrHomeController < BaseController
  def index
    menu = Menu.find_and_wrap(:hr).find { |item| item.show?(current_ability) }

    redirect_to menu.url if menu
  end
end
