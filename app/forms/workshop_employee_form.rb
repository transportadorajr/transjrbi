class WorkshopEmployeeForm < BaseForm
  attribute :name, :string
  attribute :role_type, :string, default: 'mechanic'
  attribute :active, :boolean, default: true

  enum :role_type, WorkshopEmployee::ROLES

  before_validation :normalize_name

  validates :name, :role_type, presence: true
  validates :role_type, inclusion: { in: WorkshopEmployee::ROLES.map(&:to_s) }, allow_blank: true
  validate :name_must_be_available

  attr_accessor :tenant
  attr_writer :workshop_employee

  delegate :id, :persisted?, to: :workshop_employee

  class << self
    def for_workshop_employee(workshop_employee)
      form = new(name: workshop_employee.name, role_type: workshop_employee.role_type, active: workshop_employee.active,
                 tenant: workshop_employee.tenant)
      form.workshop_employee = workshop_employee
      form
    end
  end

  def workshop_employee
    @workshop_employee ||= tenant.workshop_employees.new
  end

  def submit
    workshop_employee.update!(name:, role_type:, active:)
  end

  private

  def normalize_name
    self.name = name.to_s.squish.upcase
  end

  def name_must_be_available
    return if name.blank?

    others = persisted? ? tenant.workshop_employees.where.not(id: workshop_employee.id) : tenant.workshop_employees
    errors.add(:name, :taken) if others.exists?(name:)
  end
end
