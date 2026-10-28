class HomeController < BaseController
  def index
    redirect_to freight_billing_path if can?(:read, :freight_billing)
  end
end
