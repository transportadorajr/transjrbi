class RiskAssessment < ApplicationRecord
  include Sortable
  include Exportable

  PROVIDERS = %i[apisul opentech].freeze
  STATUSES = %i[recommended not_recommended in_progress].freeze
  APISUL_MIN_SCORE = 60
  EXPIRING_SOON_DAYS = 30

  sortable :employee_name, -> { sort_text(Employee.arel_table[:name]) }
  sortable :valid_until, -> { arel_table[:valid_until] }

  export_field(:employee) { |risk_assessment| risk_assessment.employee.name }

  belongs_to :tenant
  belongs_to :employee

  enum :provider_type, PROVIDERS.index_with(&:to_s), validate: true
  enum :status_type, STATUSES.index_with(&:to_s), validate: { allow_nil: true }

  before_validation :apply_apisul_score

  validates :provider_type, uniqueness: { scope: :employee_id }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :by_name, ->(name) { joins(:employee).merge(Employee.by_name(name)) }
  scope :by_company_type, ->(company_type) { joins(:employee).merge(Employee.by_company_type(company_type)) }
  scope :by_provider_type, ->(provider_type) { where(provider_type:) }
  scope :by_status_type, ->(status_type) { where(status_type:) }
  scope :expired, ->(date = Date.current) { where(valid_until: ...date) }
  scope :expiring, ->(date = Date.current) { where(valid_until: date..(date + EXPIRING_SOON_DAYS)) }

  private

  def apply_apisul_score
    return unless apisul? && score

    self.status_type = score < APISUL_MIN_SCORE ? :not_recommended : :recommended
  end
end

# == Schema Information
#
# Table name: risk_assessments
#
#  id            :bigint           not null, primary key
#  notes         :text
#  provider_type :enum             not null
#  score         :integer
#  status_type   :enum
#  valid_until   :date
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  employee_id   :bigint           not null
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_risk_assessments_on_employee_id_and_provider_type  (employee_id,provider_type) UNIQUE
#  index_risk_assessments_on_tenant_id                      (tenant_id)
#  index_risk_assessments_on_tenant_id_and_valid_until      (tenant_id,valid_until)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
