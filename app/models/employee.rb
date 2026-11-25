class Employee < ApplicationRecord
  include Activatable
  include Sortable

  COMPANIES = %i[transjr mme mm_espinola].freeze
  GENDERS = %i[female male].freeze
  WORK_SCHEDULES = %i[five_two not_scheduled].freeze
  SUNDAY_OFF_INTERVAL_DAYS = { 'female' => 15, 'male' => 28 }.freeze

  self.ignored_columns += %w[role]

  sortable :name

  belongs_to :tenant
  belongs_to :driver, optional: true
  belongs_to :workshop_employee, optional: true
  belongs_to :job_position, optional: true

  has_many :work_schedule_days, dependent: :delete_all
  has_many :vacations, dependent: :delete_all
  has_many :risk_assessments, dependent: :delete_all
  has_many :life_insurances, dependent: :delete_all
  has_many :emergency_contacts, -> { order(:position, :id) }, dependent: :delete_all, inverse_of: :employee

  enum :company_type, COMPANIES.index_with(&:to_s), validate: true
  enum :gender_type, GENDERS.index_with(&:to_s), validate: true
  enum :work_schedule_type, WORK_SCHEDULES.index_with(&:to_s), validate: true

  validates :name, presence: true
  validates :legal_id, uniqueness: { scope: :tenant_id }, allow_nil: true
  validates :driver_id, :workshop_employee_id, uniqueness: true, allow_nil: true

  scope :by_name, ->(name) {
    pattern = "%#{sanitize_sql_like(name)}%"
    where(arel_table[:name].matches(pattern)).or(where(arel_table[:nickname].matches(pattern)))
  }
  scope :by_company_type, ->(company_type) { where(company_type:) }
  scope :by_work_schedule_type, ->(work_schedule_type) { where(work_schedule_type:) }
  scope :without_life_insurance, ->(date = Date.current) {
    activated.where.not(id: LifeInsurance.covered_on(date).select(:employee_id))
  }
  scope :without_emergency_contact, -> { where.not(id: EmergencyContact.select(:employee_id)) }
  scope :by_emergency_contact, ->(value) { value == 'missing' ? without_emergency_contact : where(id: EmergencyContact.select(:employee_id)) }
  scope :scheduled_in, ->(dates) {
    activated.five_two.where(admitted_on: nil).or(activated.five_two.where(admitted_on: ..dates.last))
  }

  class << self
    def statuses
      {
        I18n.t('employees.status.active') => :active,
        I18n.t('employees.status.inactive') => :deactivated,
      }
    end
  end

  def driver_code
    driver&.code
  end

  def job_position_name
    job_position&.name
  end

  def sunday_off_interval
    SUNDAY_OFF_INTERVAL_DAYS.fetch(gender_type).days
  end
end

# == Schema Information
#
# Table name: employees
#
#  id                   :bigint           not null, primary key
#  activated_at         :datetime
#  admitted_on          :date
#  born_on              :date
#  company_type         :enum             not null
#  cost_center          :string
#  gender_type          :enum             not null
#  name                 :string           not null
#  nickname             :string
#  registration         :string
#  work_schedule_type   :enum             default("five_two"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  driver_id            :bigint
#  job_position_id      :bigint
#  legal_id             :string
#  tenant_id            :bigint           not null
#  workshop_employee_id :bigint
#
# Indexes
#
#  index_employees_on_driver_id               (driver_id) UNIQUE
#  index_employees_on_job_position_id         (job_position_id)
#  index_employees_on_tenant_id               (tenant_id)
#  index_employees_on_tenant_id_and_legal_id  (tenant_id,legal_id) UNIQUE
#  index_employees_on_workshop_employee_id    (workshop_employee_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (driver_id => drivers.id)
#  fk_rails_...  (job_position_id => job_positions.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (workshop_employee_id => workshop_employees.id)
#
