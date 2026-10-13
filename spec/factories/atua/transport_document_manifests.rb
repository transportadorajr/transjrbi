FactoryBot.define do
  factory :atua_transport_document_manifest, class: 'Atua::TransportDocumentManifest' do
    tenant
    sequence(:transport_document_code) { |n| 80_000 + n }
    sequence(:manifest_number) { |n| (40_700 + n).to_s }
    branch_name { 'JR TRANSPORTES' }
    imported_at { Time.current }
  end
end
