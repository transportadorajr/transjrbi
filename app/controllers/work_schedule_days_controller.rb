class WorkScheduleDaysController < BaseController
  before_action :set_work_schedule_day, only: %i[show destroy]

  def show
    authorize!(:read, :work_schedules)

    render formats: :turbo_stream
  end

  def new
    authorize!(:create, :work_schedules)

    employee = current_tenant.employees.find(params.expect(:employee_id))
    @day_form = WorkScheduleDayForm.for_employee(current_tenant, employee, entry_date)
    render formats: :turbo_stream
  end

  def create
    authorize!(:create, :work_schedules)

    @day_form = WorkScheduleDayForm.new(tenant: current_tenant, **day_params)

    if @day_form.save
      redirect_back_or_to work_schedules_path(week: @day_form.start_on.iso8601), notice: t('.success'), status: :see_other
    else
      render formats: :turbo_stream, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :work_schedules)

    @work_schedule_day.destroy!

    redirect_back_or_to work_schedules_path(week: @work_schedule_day.date.iso8601), notice: t('.success'), status: :see_other
  end

  private

  def set_work_schedule_day
    @work_schedule_day = current_tenant.work_schedule_days.preload(:employee, :city).find(params.expect(:id))
  end

  def entry_date
    Date.iso8601(params[:date].to_s)
  rescue Date::Error
    Date.current
  end

  def day_params
    params.expect(work_schedule_day: %i[employee_id kind_type start_on end_on city_id leave_reason_type notes]).to_h.symbolize_keys
  end
end
