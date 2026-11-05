FactoryBot.define do
  factory :atua_manifest, class: 'Atua::Manifest' do
    tenant
    sequence(:code) { |n| 41_000 + n }
    sequence(:number) { |n| (40_700 + n).to_s }
    series { 1 }
    model { 58 }
    branch_name { 'JR TRANSPORTES' }
    issued_on { Date.new(2026, 10, 1) }
    departure_on { Date.new(2026, 10, 1) }
    plate { 'RHJ4E07' }
    status { 'Encerrado' }
    goods_value_cents { 11_259_672 }
    imported_at { Time.current }

    trait :with_transport_document do
      after(:create) do |manifest|
        transport_document = create(:atua_transport_document, tenant: manifest.tenant, branch_name: manifest.branch_name)
        create(:atua_manifest_document, tenant: manifest.tenant, manifest_code: manifest.code, transport_document_number: transport_document.number,
                                        transport_document_series: transport_document.series, branch_name: manifest.branch_name)
      end
    end
  end
end
