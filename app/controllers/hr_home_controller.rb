class HrHomeController < BaseController
  def index
    menu = Menu.find_and_wrap(:hr).lazy.filter_map { |item| item.landing(current_ability) }.first

    redirect_to menu.url if menu
  end
end
