FactoryBot.define do
  factory :atua_device_registration, class: 'Atua::DeviceRegistration' do
    tenant
    status_type { 'code_sent' }
    masked_email { 'int*******@t******.test' }
    session_state do
      { cookies: { 'PHPSESSID' => 'abc123' }, person_id: '9430', masked_email: 'int*******@t******.test', form_fields: { 'f_origem' => 'index.php' } }.to_json
    end
    expires_at { 10.minutes.from_now }
  end
end
