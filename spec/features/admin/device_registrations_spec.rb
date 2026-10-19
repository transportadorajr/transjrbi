require 'rails_helper'
require Rails.root.join('mock/atua_server')

describe 'Admin Atua device registration', :admin do
  let!(:admin_user) { create(:admin_user) }
  let!(:tenant) { create(:tenant, trade_name: 'TransJR', atua_device_hash: nil, atua_device_token: nil) }
  let(:credentials) { { base_url: 'http://localhost:4567/adm', username: 'transjr', password: 'secret-password' } }

  around { |example| ClimateControl.modify(ATUA_MOCK_DEVICE_VERIFICATION: 'true', ATUA_MOCK_DEVICE_CODE: 'XYZ789') { example.run } }

  before do
    allow(Rails.application.credentials).to receive(:atua).and_return(credentials)
    allow_any_instance_of(Atua::Client).to receive(:pause)
    AtuaServer.set(:trusted_devices, Set.new)
    AtuaServer.set(:pending_codes, {})
    AtuaServer.set(:verified_sessions, {})
    stub_request(:any, /localhost:4567/).to_rack(AtuaServer)
    sign_in_admin(admin_user)
  end

  context 'when the Atua asks for the e-mail code', :js do
    scenario 'registers the device with the code received by e-mail' do
      visit admin_imports_path

      within("#atua_device_tenant_#{tenant.id}") do
        expect(page).to have_text('Dispositivo na Atua Não registrado', normalize_ws: true)
        accept_confirm { click_button 'Registrar dispositivo' }
      end

      within('#device_registration_modal') do
        expect(page).to have_text('A Atua enviou um código de verificação para int*******@t******.test. Informe o código abaixo em até 10 minutos.')
        fill_in 'Código de verificação', with: 'WRONG1'
        click_button 'Confirmar código'

        expect(page).to have_css('.alert-danger', text: 'Código inválido.')
        fill_in 'Código de verificação', with: 'xyz789'
        click_button 'Confirmar código'
      end

      expect(page).to have_text('Dispositivo da TransJR registrado na Atua. As próximas importações entram sem código.')
      expect(page).to have_css("#atua_device_tenant_#{tenant.id}", text: 'Registrado')
      expect(Atua::DeviceRegistration.count).to eq(1)
      expect(Atua::DeviceRegistration.last).to have_attributes(tenant_id: tenant.id, status_type: 'confirmed', session_state: nil)
      expect(tenant.reload.atua_device_hash).to match(/\A\h{64}\z/)
      expect(tenant.atua_device_token).to eq("c_ds_dispositivo_mock_9430=#{tenant.atua_device_hash}")
    end

    scenario 'fits the code modal on a phone' do
      visit admin_imports_path
      use_mobile_screen

      within("#atua_device_tenant_#{tenant.id}") { accept_confirm { click_button 'Registrar dispositivo' } }

      expect(page).to have_field('Código de verificação')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end

  context 'when the Atua already trusts the device' do
    around { |example| ClimateControl.modify(ATUA_MOCK_DEVICE_VERIFICATION: 'false') { example.run } }

    scenario 'tells that no code was sent' do
      visit admin_imports_path
      within("#atua_device_tenant_#{tenant.id}") { click_button 'Registrar dispositivo' }

      expect(page).to have_current_path(admin_imports_path)
      expect(page).to have_text('A Atua já reconhece o dispositivo da TransJR. Nenhum código foi enviado.')
      expect(Atua::DeviceRegistration.count).to eq(0)
    end
  end

  context 'when the Atua refuses the credentials' do
    let(:credentials) { { base_url: 'http://localhost:4567/adm', username: 'transjr', password: '' } }

    scenario 'shows the error of the login' do
      allow(Rails.application.credentials).to receive(:atua).and_return(credentials.merge(password: 'x'))
      stub_request(:post, 'http://localhost:4567/adm/login.php').to_return(status: 200, body: '<form><input name="f_ds_senha"></form>')

      visit admin_imports_path
      within("#atua_device_tenant_#{tenant.id}") { click_button 'Registrar dispositivo' }

      expect(page).to have_text('A Atua recusou o login, a resposta ainda contém o formulário de login.')
      expect(Atua::DeviceRegistration.count).to eq(0)
    end
  end

  context 'with a code of another tenant' do
    let!(:other_registration) { create(:atua_device_registration) }

    scenario 'does not confirm it' do
      page.driver.header('Accept', 'text/vnd.turbo-stream.html')
      page.driver.submit :patch, admin_tenant_device_registration_path(tenant),
                         { admin_device_registration: { registration_id: other_registration.id, code: 'XYZ789' } }

      expect(page.status_code).to eq(422)
      expect(other_registration.reload.status_type).to eq('code_sent')
    end
  end
end
