class DistanceAdjustmentsController < BaseController
  has_scope :by_number, as: :number
  has_scope :by_status, as: :status

  before_action :set_distance_adjustment, only: %i[edit update destroy]

  def index
    authorize!(:read, :distance_adjustments)

    @distance_adjustments = apply_sort(apply_scopes(current_tenant.distance_adjustments), DistanceAdjustment.numeric_number.asc, :id)
      .page(params[:page])
    @distance_adjustment_import_form = DistanceAdjustmentImportForm.new(tenant: current_tenant)
  end

  def new
    authorize!(:create, :distance_adjustments)

    @distance_adjustment_form = DistanceAdjustmentForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :distance_adjustments)

    @distance_adjustment_form = DistanceAdjustmentForm.for_distance_adjustment(@distance_adjustment)
  end

  def create
    authorize!(:create, :distance_adjustments)

    @distance_adjustment_form = DistanceAdjustmentForm.new(tenant: current_tenant, **distance_adjustment_params)

    if @distance_adjustment_form.save
      redirect_to distance_adjustments_path, notice: saved_notice
    else
      flash.now[:alert] = @distance_adjustment_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :distance_adjustments)

    @distance_adjustment_form = DistanceAdjustmentForm.for_distance_adjustment(@distance_adjustment)
    @distance_adjustment_form.assign_attributes(distance_adjustment_params)

    if @distance_adjustment_form.save
      redirect_to distance_adjustments_path, notice: saved_notice
    else
      flash.now[:alert] = @distance_adjustment_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :distance_adjustments)

    DistanceAdjustments::DestroyCommand.call(@distance_adjustment)
    redirect_to distance_adjustments_path, notice: t('.success')
  end

  def import
    authorize!(:create, :distance_adjustments)

    form = DistanceAdjustmentImportForm.new(tenant: current_tenant, file: params.dig(:distance_adjustment_import, :file))

    if form.save
      redirect_to distance_adjustments_path, notice: import_notice(form.result), alert: import_alert(form.result)
    else
      redirect_to distance_adjustments_path, alert: form.errors.full_messages.to_sentence
    end
  end

  private

  def set_distance_adjustment
    @distance_adjustment = current_tenant.distance_adjustments.find(params.expect(:id))
  end

  def distance_adjustment_params
    params.expect(distance_adjustment: %i[transport_document_number distance_km])
  end

  def import_notice(result)
    t('.success', created: result.created, updated: result.updated, applied: result.applied, pending: result.pending)
  end

  def import_alert(result)
    alerts = result.errors.dup
    alerts << t('.duplicated', numbers: result.duplicated_numbers.join(', ')) if result.duplicated_numbers.any?
    alerts.join(' ').presence
  end

  def saved_notice
    key = @distance_adjustment_form.documents_count.positive? ? 'applied' : 'pending'

    t("distance_adjustments.saved.#{key}", number: @distance_adjustment_form.transport_document_number)
  end
end
