FactoryBot.define do
  factory :empty_leg_transport_document do
    empty_leg
    tenant { empty_leg.tenant }
    sequence(:transport_document_code) { |n| 80_000 + n }
  end
end
