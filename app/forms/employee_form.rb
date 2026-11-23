class EmployeeForm < BaseForm
  CPF_LENGTH = 11

  attribute :name, :string
  attribute :nickname, :string
  attribute :legal_id, :string
  attribute :company_type, :string
  attribute :registration, :string
  attribute :job_position_id, :integer
  attribute :cost_center, :string
  attribute :gender_type, :string
  attribute :born_on, :date
  attribute :admitted_on, :date
  attribute :work_schedule_type, :string, default: 'five_two'
  attribute :workshop_employee_id, :integer
  attribute :active, :boolean, default: true

  enum :company_type, Employee::COMPANIES
  enum :gender_type, Employee::GENDERS
  enum :work_schedule_type, Employee::WORK_SCHEDULES

  before_validation :normalize_fields

  validates :name, :legal_id, :company_type, :gender_type, :work_schedule_type, presence: true
  validates :company_type, inclusion: { in: Employee::COMPANIES.map(&:to_s) }, allow_blank: true
  validates :gender_type, inclusion: { in: Employee::GENDERS.map(&:to_s) }, allow_blank: true
  validates :work_schedule_type, inclusion: { in: Employee::WORK_SCHEDULES.map(&:to_s) }, allow_blank: true
  validate :legal_id_must_be_a_valid_cpf
  validate :legal_id_must_be_available
  validate :admitted_on_must_follow_born_on
  validate :workshop_employee_must_be_available
  validate :job_position_must_be_available

  attr_accessor :tenant
  attr_writer :employee

  delegate :id, :persisted?, to: :employee

  class << self
    def for_employee(employee)
      form = new(
        name: employee.name, nickname: employee.nickname, legal_id: employee.legal_id, company_type: employee.company_type,
        registration: employee.registration, job_position_id: employee.job_position_id, cost_center: employee.cost_center,
        gender_type: employee.gender_type, born_on: employee.born_on, admitted_on: employee.admitted_on,
        work_schedule_type: employee.work_schedule_type, workshop_employee_id: employee.workshop_employee_id,
        active: employee.activated?, tenant: employee.tenant
      )
      form.employee = employee
      form
    end
  end

  def employee
    @employee ||= tenant.employees.new
  end

  def available_workshop_employees
    linked_ids = tenant.employees.where.not(id: employee.id).where.not(workshop_employee_id: nil).select(:workshop_employee_id)

    tenant.workshop_employees.where.not(id: linked_ids).order(:name)
  end

  def available_job_positions
    tenant.job_positions.activated.or(tenant.job_positions.where(id: employee.job_position_id)).order(:name)
  end

  def submit
    transaction do
      employee.update!(
        name:, nickname:, legal_id:, company_type:, registration:, job_position_id:, cost_center:, gender_type:, born_on:,
        admitted_on:, work_schedule_type:, workshop_employee_id:, activated: active
      )
      Employees::LinkDriverCommand.call(employee) unless activation_only?
    end
  end

  private

  def normalize_fields
    self.name = name.to_s.squish.upcase
    self.nickname = nickname.to_s.squish.upcase.presence
    self.legal_id = legal_id.to_s.gsub(/\D/, '')
    self.registration = registration.to_s.squish.presence
    self.cost_center = cost_center.to_s.squish.upcase.presence
  end

  def legal_id_must_be_a_valid_cpf
    return if legal_id.blank? || valid_cpf?(legal_id)

    errors.add(:legal_id, :invalid)
  end

  def valid_cpf?(digits)
    return false unless digits.length == CPF_LENGTH && digits.squeeze.length > 1

    numbers = digits.chars.map(&:to_i)

    [9, 10].all? { |size| cpf_check_digit(numbers.first(size)) == numbers[size] }
  end

  def cpf_check_digit(numbers)
    sum = numbers.each_with_index.sum { |number, index| number * (numbers.length + 1 - index) }
    remainder = sum % 11

    remainder < 2 ? 0 : 11 - remainder
  end

  def legal_id_must_be_available
    return if legal_id.blank?

    errors.add(:legal_id, :taken) if other_employees.exists?(legal_id:)
  end

  def admitted_on_must_follow_born_on
    return if born_on.blank? || admitted_on.blank? || admitted_on > born_on

    errors.add(:admitted_on, :before_born_on)
  end

  def workshop_employee_must_be_available
    return if workshop_employee_id.blank?

    errors.add(:workshop_employee_id, :invalid) unless available_workshop_employees.exists?(id: workshop_employee_id)
  end

  def job_position_must_be_available
    return if job_position_id.blank?

    errors.add(:job_position_id, :invalid) unless available_job_positions.exists?(id: job_position_id)
  end

  def other_employees
    persisted? ? tenant.employees.where.not(id: employee.id) : tenant.employees
  end
end
