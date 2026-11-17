FactoryBot.define do
  factory :maintenance_order_signature do
    maintenance_order
    tenant { maintenance_order.tenant }
    workshop_employee { association :workshop_employee, tenant: maintenance_order.tenant }
    signer_role_type { 'mechanic' }
    signer_name { workshop_employee.name }
    strokes { SignatureHelpers::SAMPLE_STROKES }
    signed_at { Time.zone.local(2026, 11, 11, 17, 30) }
    content_digest { Digest::SHA256.hexdigest('OS') }
  end
end
