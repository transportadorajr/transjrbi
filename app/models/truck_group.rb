class TruckGroup < ApplicationRecord
  NONE = 'none'.freeze
  AXLE_OPTIONS = (2..9).to_a.freeze

  belongs_to :tenant
  has_many :freight_expenses, inverse_of: :truck_group, dependent: :restrict_with_error

  time_based_flag :activated

  validates :name, presence: true, uniqueness: { scope: :tenant_id }
  validates :axles, presence: true, unless: -> { remaining_axles? || plates.any? }
  validates :fuel_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

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

  def fuel_cents(freight_cents)
    (freight_cents.to_d * fuel_percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
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
