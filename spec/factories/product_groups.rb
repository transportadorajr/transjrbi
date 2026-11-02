FactoryBot.define do
  factory :product_group do
    tenant
    sequence(:name) { |n| "GRUPO #{n}" }
    activated_at { Time.current }

    factory :product_subgroup do
      parent { association(:product_group, tenant:) }
      product_names { [] }
    end
  end
end
