FactoryBot.define do
  factory :maintenance_part_movement do
    maintenance_part
    tenant { maintenance_part.tenant }
    movement_type { :entry }
    moved_on { Date.current }
    quantity { 1 }
    balance { 1 }
  end
end
