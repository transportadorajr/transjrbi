FactoryBot.define do
  factory :workshop_employee do
    tenant
    sequence(:name) { |n| "MECÂNICO #{n}" }
    role_type { 'mechanic' }
    active { true }
  end
end
