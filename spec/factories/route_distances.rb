FactoryBot.define do
  factory :route_distance do
    tenant
    sequence(:customer_code) { |n| 7000 + n }
    origin_city { 'IPATINGA' }
    origin_state { 'MG' }
    destination_city { 'CAXIAS DO SUL' }
    destination_state { 'RS' }
    distance_km { BigDecimal('1450') }
  end
end
