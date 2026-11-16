class GoalsController < BaseController
  CACHE_TTL = 1.hour

  before_action :require_revenue_goals

  def show
    authorize!(:read, :goals)

    @filter_form = GoalFilterForm.new(month: params[:month], dimension: params[:dimension])
    return redirect_to(goals_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @last_synced_at = current_tenant.last_synced_at
    @dashboard = Dashboard::Goals.new(current_tenant.billable_freights, targets:, pace:, week:, own_fleet: current_tenant.own_fleet)
    @rows = listing_page(dimension_rows)
  end

  private

  def dimension_rows
    return @dashboard.sorted_vehicle_rows(params[:sort], params[:direction]) if @filter_form.section == :vehicles

    @dashboard.breakdown_rows(@filter_form.section)
  end

  def month
    @filter_form.month_value
  end

  def targets
    @targets ||= RevenueGoal::Targets.new(current_tenant, month)
  end

  def week
    return unless month.all_month.cover?(reference_date)

    period = reference_date.all_week(RevenueGoal::Week::WEEK_START)
    RevenueGoal::Week.new(reference_date, goals: current_tenant.revenue_goals.where(month: period.first.beginning_of_month..period.last).to_a,
                                          holidays: holidays(period.first.beginning_of_month..period.last.end_of_month))
  end

  def require_revenue_goals
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::Goals.enabled?(current_tenant)
  end

  def pace
    RevenueGoal::Pace.new(month, reference_date:, holidays: holidays(month.all_month), projection: (projection if @filter_form.current_month?))
  end

  def holidays(dates)
    current_tenant.holidays.where(date: dates).index_by(&:date)
  end

  def reference_date
    @reference_date ||= (@last_synced_at || Time.current).to_date
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
