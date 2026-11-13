class RevenueProjectionsController < BaseController
  CACHE_TTL = 1.hour

  before_action :require_revenue_projection

  def show
    authorize!(:read, :revenue_projection)

    @last_synced_at = current_tenant.last_synced_at
    @period_type = Dashboard::RevenueProjection.sanitize_period_type(params[:period])
    @projection = Dashboard::RevenueProjection.new(projection(@period_type.to_sym))

    respond_with_listing(pdf: false, xlsx: -> { helpers.revenue_projection_xlsx_sheets(@projection) })
  end

  private

  def require_revenue_projection
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::RevenueProjection.enabled?(current_tenant)
  end

  def projection(period_type)
    Rails.cache.fetch(projection_cache_key(period_type), expires_in: CACHE_TTL) do
      RevenueProjections::CalculateCommand.call(current_tenant, period_type:)
    end
  end

  def projection_cache_key(period_type)
    [
      :revenue_projection, current_tenant.id, period_type, Date.current, @last_synced_at || Time.current.beginning_of_hour,
      current_tenant.holidays.cache_key_with_version, current_tenant.excluded_issuers.cache_key_with_version
    ]
  end
end
