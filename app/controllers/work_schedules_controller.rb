class WorkSchedulesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type

  def index
    authorize!(:read, :work_schedules)

    @schedule = Dashboard::WorkSchedule.new(tenant: current_tenant, week: params[:week])
    @employees = listing_page(apply_sort(apply_scopes(@schedule.employees), :name, :id))
    @rows = @schedule.rows(@employees)

    respond_with_listing(orientation: :landscape, xlsx: -> { helpers.work_schedule_xlsx_sheets(@schedule, @rows) })
  end
end
