FactoryBot.define do
  factory :job_position do
    tenant
    sequence(:name) { |n| "CARGO #{n}" }
  end
end
