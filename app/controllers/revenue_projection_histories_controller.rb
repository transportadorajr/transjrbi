class RevenueProjectionHistoriesController < BaseController
  before_action :require_revenue_projection

  def show
    authorize!(:read, :revenue_projection)

    @history = Dashboard::RevenueProjectionHistory.new(current_tenant, params[:month])
  end

  private

  def require_revenue_projection
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::RevenueProjection.enabled?(current_tenant)
  end
end
