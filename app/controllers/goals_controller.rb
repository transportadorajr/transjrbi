class GoalsController < BaseController
  CACHE_TTL = 1.hour

  before_action :require_revenue_goals

  def show
    authorize!(:read, :goals)

    @filter_form = GoalFilterForm.new(month: params[:month])
    return redirect_to(goals_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @last_synced_at = current_tenant.last_synced_at
    @dashboard = Dashboard::Goals.new(current_tenant.billable_freights, goals:, pace:, own_fleet: current_tenant.own_fleet)
    @vehicle_rows = @dashboard.sorted_vehicle_rows(params[:sort], params[:direction])
  end

  private

  def goals
    current_tenant.revenue_goals.for_month(@filter_form.month_value).to_a
  end

  def require_revenue_goals
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::Goals.enabled?(current_tenant)
  end

  def pace
    month = @filter_form.month_value
    holidays = current_tenant.holidays.where(date: month.all_month).index_by(&:date)

    RevenueGoal::Pace.new(month, reference_date:, holidays:, projection: (projection if @filter_form.current_month?))
  end

  def reference_date
    (@last_synced_at || Time.current).to_date
  end

  def projection
    return unless Dashboard::RevenueProjection.enabled?(current_tenant)

    Rails.cache.fetch(projection_cache_key, expires_in: CACHE_TTL) do
      RevenueProjections::CalculateCommand.call(current_tenant, period_type: :month)
    end
  end

  def projection_cache_key
    [
      :revenue_goals_projection, current_tenant.id, Date.current, @last_synced_at || Time.current.beginning_of_hour,
      current_tenant.holidays.cache_key_with_version, current_tenant.excluded_issuers.cache_key_with_version
    ]
  end
end
