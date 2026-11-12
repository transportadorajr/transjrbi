FactoryBot.define do
  factory :own_fleet do
    tenant
    plates { %w[AJR4391 RHJ5A50] }
  end
end
