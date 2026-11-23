FactoryBot.define do
  factory :employee do
    tenant
    sequence(:name) { |n| "FUNCIONÁRIO #{n}" }
    legal_id { '52998224725' }
    company_type { 'transjr' }
    gender_type { 'male' }
    work_schedule_type { 'five_two' }
  end
end
