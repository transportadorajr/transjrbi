FactoryBot.define do
  factory :vacation do
    employee { association :employee, admitted_on: Date.new(2024, 3, 10) }
    tenant { employee.tenant }
    acquisition_start_on { employee.admitted_on }
    start_on { Date.new(2025, 4, 1) }
    end_on { start_on + 29 }
  end
end
