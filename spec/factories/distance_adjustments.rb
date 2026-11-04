FactoryBot.define do
  factory :distance_adjustment do
    tenant
    sequence(:transport_document_number) { |n| (74_000 + n).to_s }
    distance_km { BigDecimal('450') }
  end
end
