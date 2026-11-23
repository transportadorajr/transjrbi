class WorkScheduleDay < ApplicationRecord
  KINDS = %i[day_off leave].freeze
  LEAVE_REASONS = %i[medical_appointment medical_certificate].freeze

  belongs_to :tenant
  belongs_to :employee
  belongs_to :city, optional: true

  enum :kind_type, KINDS.index_with(&:to_s), validate: true
  enum :leave_reason_type, LEAVE_REASONS.index_with(&:to_s), validate: { allow_nil: true }

  validates :date, presence: true, uniqueness: { scope: :employee_id }
  validates :leave_reason_type, presence: true, if: :leave?
  validates :leave_reason_type, absence: true, unless: :leave?

  scope :by_period, ->(dates) { where(date: dates) }
end

# == Schema Information
#
# Table name: work_schedule_days
#
#  id                :bigint           not null, primary key
#  date              :date             not null
#  kind_type         :enum             not null
#  leave_reason_type :enum
#  notes             :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  city_id           :bigint
#  employee_id       :bigint           not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_work_schedule_days_on_city_id               (city_id)
#  index_work_schedule_days_on_employee_id_and_date  (employee_id,date) UNIQUE
#  index_work_schedule_days_on_tenant_id             (tenant_id)
#  index_work_schedule_days_on_tenant_id_and_date    (tenant_id,date)
#
# Foreign Keys
#
#  fk_rails_...  (city_id => cities.id) ON DELETE => nullify
#  fk_rails_...  (employee_id => employees.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
