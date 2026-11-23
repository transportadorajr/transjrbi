class JobPositionsController < BaseController
  include Activation

  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :set_job_position, only: %i[edit update activate deactivate]

  def index
    authorize!(:read, :job_positions)

    @job_positions = listing_page(apply_sort(apply_scopes(current_tenant.job_positions), :name, :id))
    @employee_counts = current_tenant.employees.where(job_position_id: @job_positions.map(&:id)).group(:job_position_id).count
  end

  def new
    authorize!(:create, :job_positions)

    @job_position_form = JobPositionForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :job_positions)

    @job_position_form = JobPositionForm.for_job_position(@job_position)
  end

  def create
    authorize!(:create, :job_positions)

    @job_position_form = JobPositionForm.new(tenant: current_tenant, **job_position_params)

    if @job_position_form.save
      redirect_to job_positions_path, notice: t('.success')
    else
      flash.now[:alert] = @job_position_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :job_positions)

    @job_position_form = JobPositionForm.for_job_position(@job_position)
    @job_position_form.assign_attributes(job_position_params)

    if @job_position_form.save
      redirect_to job_positions_path, notice: t('.success')
    else
      flash.now[:alert] = @job_position_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def activation_form
    JobPositionForm.for_job_position(@job_position)
  end

  def set_job_position
    @job_position = current_tenant.job_positions.find(params.expect(:id))
  end

  def job_position_params
    params.expect(job_position: %i[name active])
  end
end
