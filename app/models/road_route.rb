class RoadRoute < ApplicationRecord
  belongs_to :origin, class_name: 'Location'
  belongs_to :destination, class_name: 'Location'

  validates :distance_km, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :destination_id, uniqueness: { scope: :origin_id }
end

# == Schema Information
#
# Table name: road_routes
#
#  id                  :bigint           not null, primary key
#  distance_km         :decimal(14, 2)   not null
#  travel_time_seconds :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  destination_id      :bigint           not null
#  origin_id           :bigint           not null
#
# Indexes
#
#  index_road_routes_on_destination_id                (destination_id)
#  index_road_routes_on_origin_id_and_destination_id  (origin_id,destination_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (destination_id => locations.id)
#  fk_rails_...  (origin_id => locations.id)
#
