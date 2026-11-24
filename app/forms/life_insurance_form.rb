class LifeInsuranceForm < BaseForm
  attribute :employee_id, :integer
  attribute :included_on, :date
  attribute :capital, :string
  attribute :capital_changed_on, :date

  validates :employee, presence: true
  validates :included_on, presence: true, on: :create
  validate :employee_must_be_insurable, on: :create
  validate :employee_must_have_the_insurer_data, on: :create
  validate :policy_must_exist
  validate :capital_must_be_positive
  validate :capital_change_must_have_a_date, on: :update

  attr_accessor :tenant
  attr_writer :life_insurance

  delegate :id, :persisted?, to: :life_insurance

  class << self
    def for_life_insurance(life_insurance)
      form = new(tenant: life_insurance.tenant, employee_id: life_insurance.employee_id, included_on: life_insurance.included_on,
                 capital: format_cents(life_insurance[:capital_cents]), capital_changed_on: life_insurance.capital_changed_on)
      form.life_insurance = life_insurance
      form
    end
  end

  def life_insurance
    @life_insurance ||= tenant.life_insurances.new
  end

  def employee
    return if employee_id.blank?

    return @employee if @employee&.id == employee_id

    @employee = tenant.employees.find_by(id: employee_id)
  end

  def policy
    employee && tenant.life_insurance_policies.find_by(company_type: employee.company_type)
  end

  def available_employees
    tenant.employees.activated.where.not(id: open_insurance_employee_ids).or(tenant.employees.where(id: employee_id)).order(:name)
  end

  def capital_changed?
    persisted? && self.class.parse_cents(capital) != life_insurance[:capital_cents]
  end

  def submit
    life_insurance.update!(
      employee:, life_insurance_policy: policy, included_on:, capital_cents: self.class.parse_cents(capital),
      capital_changed_on: capital_changed? ? capital_changed_on : life_insurance.capital_changed_on
    )
  end

  private

  def open_insurance_employee_ids
    tenant.life_insurances.where(excluded_on: nil).select(:employee_id)
  end

  def employee_must_be_insurable
    return if employee.nil?

    errors.add(:employee_id, :inactive) unless employee.activated?
    errors.add(:employee_id, :already_insured) if employee.life_insurances.exists?(excluded_on: nil)
  end

  def employee_must_have_the_insurer_data
    return if employee.nil? || (employee.legal_id.present? && employee.born_on.present?)

    errors.add(:employee_id, :missing_insurer_data)
  end

  def policy_must_exist
    return if employee.nil? || policy

    errors.add(:employee_id, :without_policy, company: employee.company_type_name)
  end

  def capital_must_be_positive
    return if capital.blank? || self.class.parse_cents(capital)&.positive?

    errors.add(:capital, :greater_than, count: 0)
  end

  def capital_change_must_have_a_date
    return unless capital_changed?

    if capital_changed_on.nil?
      errors.add(:capital_changed_on, :blank)
    elsif included_on && capital_changed_on < included_on
      errors.add(:capital_changed_on, :before_included_on)
    end
  end
end
