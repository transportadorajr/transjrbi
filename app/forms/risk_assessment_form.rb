class RiskAssessmentForm < BaseForm
  attribute :employee_id, :integer
  attribute :provider_type, :string
  attribute :status_type, :string
  attribute :score, :integer
  attribute :valid_until, :date
  attribute :notes, :string

  before_validation :normalize_fields

  validates :employee, :provider_type, presence: true
  validates :provider_type, inclusion: { in: RiskAssessment.provider_types.keys }, allow_blank: true
  validates :status_type, inclusion: { in: RiskAssessment.status_types.keys }, allow_blank: true
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :provider_must_be_available

  attr_accessor :tenant
  attr_writer :risk_assessment

  delegate :id, :persisted?, to: :risk_assessment

  class << self
    def for_risk_assessment(risk_assessment)
      form = new(tenant: risk_assessment.tenant, employee_id: risk_assessment.employee_id, provider_type: risk_assessment.provider_type,
                 status_type: risk_assessment.status_type, score: risk_assessment.score, valid_until: risk_assessment.valid_until,
                 notes: risk_assessment.notes)
      form.risk_assessment = risk_assessment
      form
    end
  end

  def risk_assessment
    @risk_assessment ||= tenant.risk_assessments.new
  end

  def employee
    return if employee_id.blank?

    return @employee if @employee&.id == employee_id

    @employee = tenant.employees.find_by(id: employee_id)
  end

  def available_employees
    tenant.employees.activated.or(tenant.employees.where(id: employee_id)).order(:name)
  end

  def submit
    risk_assessment.update!(employee:, provider_type:, status_type:, score:, valid_until:, notes:)
  end

  private

  def normalize_fields
    self.status_type = status_type.presence
    self.notes = notes.to_s.squish.presence
  end

  def provider_must_be_available
    return if employee.nil? || provider_type.blank?

    others = employee.risk_assessments.where(provider_type:)
    others = others.where.not(id: risk_assessment.id) if persisted?
    errors.add(:provider_type, :taken) if others.exists?
  end
end
