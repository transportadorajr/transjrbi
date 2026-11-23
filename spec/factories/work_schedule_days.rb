FactoryBot.define do
  factory :work_schedule_day do
    employee
    tenant { employee.tenant }
    date { Date.new(2026, 11, 24) }
    kind_type { 'day_off' }

    trait :leave do
      kind_type { 'leave' }
      leave_reason_type { 'medical_certificate' }
    end
  end
end
