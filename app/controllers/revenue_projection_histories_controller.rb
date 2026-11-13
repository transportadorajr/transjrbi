class RevenueProjectionHistoriesController < BaseController
  before_action :require_revenue_projection

  def show
    authorize!(:read, :revenue_projection)

    @filter_form = RevenueProjectionHistoryFilterForm.new(filter_params)
    return redirect_to(revenue_projection_history_path, alert: @filter_form.errors.full_messages.to_sentence) if @filter_form.invalid?

    @history = history

    respond_with_listing(pdf: false, xlsx: -> { helpers.revenue_projection_history_xlsx_sheets(@history) })
  end

  private

  def require_revenue_projection
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::RevenueProjection.enabled?(current_tenant)
  end

  def history
    return Dashboard::RevenueProjectionToday.new(current_tenant) if @filter_form.period_type == 'today'

    Dashboard::RevenueProjectionHistory.new(current_tenant, @filter_form.period_type, @filter_form.date_range)
  end

  def filter_params
    params.permit(:start_date, :end_date, :period, :start)
  end
end
