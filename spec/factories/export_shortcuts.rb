FactoryBot.define do
  factory :export_shortcut do
    tenant
    sequence(:name) { |n| "ATALHO #{n}" }
    export_plant_ids { [] }
    countries { [] }
    position { 0 }
    activated_at { Time.current }
  end
end
