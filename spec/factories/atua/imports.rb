FactoryBot.define do
  factory :atua_import, class: 'Atua::Import' do
    tenant
    report_type { 'transport_documents' }
    status_type { 'pending' }
    start_date { Date.new(2026, 10, 1) }
    end_date { Date.new(2026, 10, 13) }

    trait :with_file do
      after(:build) do |import|
        import.file.attach(io: StringIO.new('xls'), filename: 'rel_ctrc_detalhado.xls', content_type: 'application/vnd.ms-excel')
      end
    end
  end
end
