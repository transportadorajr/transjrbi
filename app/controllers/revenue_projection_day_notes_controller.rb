class RevenueProjectionDayNotesController < BaseController
  before_action :require_revenue_projection
  before_action :set_date

  def edit
    authorize!(:update, :revenue_projection_notes)

    @day_note_form = RevenueProjectionDayNoteForm.for_date(current_tenant, @date)
    render formats: :turbo_stream
  end

  def update
    authorize!(:update, :revenue_projection_notes)

    @day_note_form = RevenueProjectionDayNoteForm.new(tenant: current_tenant, user: current_user, date: @date, **day_note_params)

    if @day_note_form.save
      redirect_to history_path, notice: t('.success'), status: :see_other
    else
      render formats: :turbo_stream, status: :unprocessable_content
    end
  end

  private

  def require_revenue_projection
    raise ActionController::RoutingError, 'Not Found' unless Dashboard::RevenueProjection.enabled?(current_tenant)
  end

  def set_date
    @date = Date.iso8601(params[:date])
  rescue Date::Error
    raise ActionController::RoutingError, 'Not Found'
  end

  def history_path
    period = Dashboard::RevenueProjectionHistory.sanitize_period_type(params[:period])

    revenue_projection_history_path(period:, start: Dashboard::RevenueProjectionHistory.period_start(period, @date).iso8601)
  end

  def day_note_params
    params.expect(revenue_projection_day_note: %i[body]).to_h.symbolize_keys
  end
end
