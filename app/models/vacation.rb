class Vacation < ApplicationRecord
  include Sortable
  include Exportable

  sortable :start_on, -> { arel_table[:start_on] }
  sortable :employee_name, -> { sort_text(Employee.arel_table[:name]) }

  export_field(:employee) { |vacation| vacation.employee.name }
  export_field(:days_count, :integer, &:days_count)
  export_field(:returns_on, :date, &:returns_on)

  belongs_to :tenant
  belongs_to :employee

  validates :acquisition_start_on, :start_on, :end_on, presence: true
  validates :sold_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :overlapping, ->(dates) { where(start_on: ..dates.last, end_on: dates.first..) }
  scope :by_name, ->(name) { joins(:employee).merge(Employee.by_name(name)) }
  scope :by_company_type, ->(company_type) { joins(:employee).merge(Employee.by_company_type(company_type)) }
  scope :by_month, ->(month) { overlapping(month_dates(month)) }

  class << self
    def month_dates(month)
      Date.strptime(month.to_s, '%Y-%m').all_month
    rescue Date::Error
      Date.current.all_month
    end
  end

  def acquisition_end_on
    acquisition_start_on.next_year - 1
  end

  def dates
    start_on..end_on
  end

  def days_count
    (end_on - start_on).to_i + 1
  end

  def returns_on
    end_on + 1
  end
end

# == Schema Information
#
# Table name: vacations
#
#  id                   :bigint           not null, primary key
#  acquisition_start_on :date             not null
#  end_on               :date             not null
#  notes                :text
#  sold_days            :integer          default(0), not null
#  start_on             :date             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  employee_id          :bigint           not null
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_vacations_on_employee_id               (employee_id)
#  index_vacations_on_employee_id_and_start_on  (employee_id,start_on)
#  index_vacations_on_tenant_id                 (tenant_id)
#  index_vacations_on_tenant_id_and_start_on    (tenant_id,start_on)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
