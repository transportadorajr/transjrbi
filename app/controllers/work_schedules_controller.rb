class WorkSchedulesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :work_schedules)

    @schedule = Dashboard::WorkSchedule.new(tenant: current_tenant, week: params[:week])
    rows = @schedule.rows(apply_sort(apply_scopes(@schedule.employees), :name, :id))
    @alert_counts = @schedule.alert_counts(rows)
    @rows = listing_page(@schedule.with_alert(rows, params[:alert]))

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.work_schedule_xlsx_sheets(@schedule, @rows) })
  end

  def show
    authorize!(:read, :work_schedules)

    @schedule = Dashboard::WorkSchedule.new(tenant: current_tenant, week: params[:week])
    @row = @schedule.rows([@schedule.employees.find(params.expect(:id))]).first
  end
end
