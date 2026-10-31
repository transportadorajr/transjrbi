class TruckGroupFuelRate < ApplicationRecord
  belongs_to :truck_group, inverse_of: :fuel_rates

  validates :valid_month, presence: true, uniqueness: { scope: :truck_group_id }
  validates :percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  class << self
    def for_month(rates, month)
      rates.select { |rate| rate.valid_month <= month }.max_by(&:valid_month) || rates.min_by(&:valid_month)
    end
  end
end

# == Schema Information
#
# Table name: truck_group_fuel_rates
#
#  id             :bigint           not null, primary key
#  percentage     :decimal(7, 4)    not null
#  valid_month    :date             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  truck_group_id :bigint           not null
#
# Indexes
#
#  index_truck_group_fuel_rates_on_truck_group_id_and_valid_month  (truck_group_id,valid_month) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (truck_group_id => truck_groups.id) ON DELETE => cascade
#
