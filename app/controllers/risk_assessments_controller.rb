class RiskAssessmentsController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_company_type, as: :company_type
  has_scope :by_provider_type, as: :provider_type
  has_scope :by_status_type, as: :status_type

  before_action :set_risk_assessment, only: %i[edit update destroy]

  def index
    authorize!(:read, :risk_assessments)

    risk_assessments = current_tenant.risk_assessments.joins(:employee).preload(:employee)
    @risk_assessments = listing_page(apply_sort(apply_scopes(risk_assessments), Employee.arel_table[:name].asc, provider_type: :asc, id: :asc))

    respond_with_listing(orientation: :landscape, xlsx: @risk_assessments)
  end

  def new
    authorize!(:create, :risk_assessments)

    @risk_assessment_form = RiskAssessmentForm.new(tenant: current_tenant, employee_id: params[:employee_id])
  end

  def edit
    authorize!(:update, :risk_assessments)

    @risk_assessment_form = RiskAssessmentForm.for_risk_assessment(@risk_assessment)
  end

  def create
    authorize!(:create, :risk_assessments)

    @risk_assessment_form = RiskAssessmentForm.new(tenant: current_tenant, **risk_assessment_params)

    if @risk_assessment_form.save
      redirect_to risk_assessments_path, notice: t('.success')
    else
      flash.now[:alert] = @risk_assessment_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :risk_assessments)

    @risk_assessment_form = RiskAssessmentForm.for_risk_assessment(@risk_assessment)
    @risk_assessment_form.assign_attributes(risk_assessment_params.except(:employee_id))

    if @risk_assessment_form.save
      redirect_to risk_assessments_path, notice: t('.success')
    else
      flash.now[:alert] = @risk_assessment_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :risk_assessments)

    @risk_assessment.destroy!
    redirect_to risk_assessments_path, notice: t('.success'), status: :see_other
  end

  private

  def set_risk_assessment
    @risk_assessment = current_tenant.risk_assessments.preload(:employee).find(params.expect(:id))
  end

  def risk_assessment_params
    params.expect(risk_assessment: %i[employee_id provider_type status_type score valid_until notes]).to_h.symbolize_keys
  end
end
