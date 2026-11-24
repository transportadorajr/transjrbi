FactoryBot.define do
  factory :life_insurance do
    employee
    tenant { employee.tenant }
    life_insurance_policy do
      tenant.life_insurance_policies.find_by(company_type: employee.company_type) ||
        association(:life_insurance_policy, tenant:, company_type: employee.company_type)
    end
  end
end
