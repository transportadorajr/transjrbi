FactoryBot.define do
  factory :access do
    user
    resource
    tenant { user.tenant }
    reads { true }
    creates { false }
  end
end
