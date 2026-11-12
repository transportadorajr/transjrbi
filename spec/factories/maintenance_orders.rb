FactoryBot.define do
  factory :maintenance_order do
    tenant
    sequence(:number) { |n| 1000 + n }
    plate { 'EXU1A23' }
    opened_at { Time.zone.local(2026, 11, 11, 8, 30) }
    equipment_type { 'truck_tractor' }
    maintenance_type { 'corrective' }
    priority_type { 'medium' }
    execution_place_type { 'internal_workshop' }
    affected_system_type { 'brakes' }
    reported_defect { 'Freio puxando para a direita' }
  end
end
