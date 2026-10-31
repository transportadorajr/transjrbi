class TruckGroup < ApplicationRecord
  include Sortable

  NONE = 'none'.freeze
  AXLE_OPTIONS = (2..9).to_a.freeze

  sortable :name

  belongs_to :tenant
  has_many :freight_expenses, inverse_of: :truck_group, dependent: :restrict_with_error
  has_many :fuel_rates, class_name: 'TruckGroupFuelRate', inverse_of: :truck_group, dependent: :destroy

  time_based_flag :activated

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :axles, presence: true, unless: -> { remaining_axles? || plates.any? }
  validates :fuel_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  after_create :record_initial_fuel_rate

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }

  class << self
    def statuses
      {
        I18n.t('truck_groups.index.active') => :active,
        I18n.t('truck_groups.index.deactivated') => :deactivated,
      }
    end

    def for_document(truck_groups, plate:, axles:)
      truck_groups.find { |truck_group| truck_group.plates.include?(plate) } ||
        truck_groups.find { |truck_group| truck_group.axles.include?(axles) } ||
        truck_groups.find(&:remaining_axles?)
    end
  end

  def fuel_cents(freight_cents, percentage = fuel_percentage)
    (freight_cents.to_d * percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def fueled?
    fuel_rates.any? { |rate| rate.percentage.positive? }
  end

  def fuel_percentage_for(month)
    return fuel_percentage if month.nil?

    TruckGroupFuelRate.for_month(fuel_rates.to_a, month)&.percentage || fuel_percentage
  end

  def change_fuel_percentage(percentage, valid_month)
    return if fuel_percentage_for(valid_month) == percentage

    keep_previous_months(valid_month)
    fuel_rates.find_or_initialize_by(valid_month:).update!(percentage:)
    fuel_rates.reset
    update!(fuel_percentage: fuel_percentage_for(Date.current.beginning_of_month))
  end

  private

  def record_initial_fuel_rate
    fuel_rates.create!(valid_month: Date.current.beginning_of_month, percentage: fuel_percentage)
  end

  def keep_previous_months(valid_month)
    return if fuel_rates.any? { |rate| rate.valid_month < valid_month }

    fuel_rates.create!(valid_month: valid_month.prev_month, percentage: fuel_percentage_for(valid_month))
  end
end

# == Schema Information
#
# Table name: truck_groups
#
#  id              :bigint           not null, primary key
#  activated_at    :datetime
#  axles           :integer          default([]), not null, is an Array
#  fuel_percentage :decimal(7, 4)    default(0.0), not null
#  name            :string           not null
#  plates          :string           default([]), not null, is an Array
#  remaining_axles :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tenant_id       :bigint           not null
#
# Indexes
#
#  index_truck_groups_on_remaining_axles     (tenant_id) UNIQUE WHERE (remaining_axles AND (activated_at IS NOT NULL))
#  index_truck_groups_on_tenant_id           (tenant_id)
#  index_truck_groups_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
