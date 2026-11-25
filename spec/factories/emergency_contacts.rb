FactoryBot.define do
  factory :emergency_contact do
    employee
    tenant { employee.tenant }
    name { 'Maria da Silva' }
    relationship_type { 'spouse' }
    phone { '45999848077' }
    position { 1 }
  end
end
