class RevenueProjectionsController < BaseController
  PERIOD_TYPES = %i[month week].freeze
  CACHE_TTL = 1.hour

  before_action :require_revenue_projection

  def show
    authorize!(:read, :revenue_projection)

    @last_synced_at = current_tenant.last_synced_at
    @month, @week = PERIOD_TYPES.map { |period_type| Dashboard::RevenueProjection.new(projection(period_type)) }
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
