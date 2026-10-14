FactoryBot.define do
  factory :atua_manifest_document, class: 'Atua::ManifestDocument' do
    tenant
    sequence(:manifest_code) { |n| 41_000 + n }
    sequence(:transport_document_number) { |n| (74_000 + n).to_s }
    transport_document_series { 1 }
    branch_name { 'JR TRANSPORTES' }
    freight_cents { 321_720 }
    imported_at { Time.current }
  end
end
