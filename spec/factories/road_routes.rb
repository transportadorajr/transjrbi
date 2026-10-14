FactoryBot.define do
  factory :road_route do
    origin factory: :location
    destination factory: :location
    distance_km { BigDecimal('217.4') }
    travel_time_seconds { 10_800 }
  end
end
