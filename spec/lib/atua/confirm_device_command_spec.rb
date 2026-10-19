require 'rails_helper'

RSpec.describe Atua::ConfirmDeviceCommand do
  let(:tenant) { create(:tenant, atua_device_hash: nil, atua_device_token: nil) }
  let(:registration) { create(:atua_device_registration, tenant:) }
  let(:client) { instance_double(Atua::Client) }
  let(:device) { Atua::Client::Device.new(device_hash: 'a' * 64, device_cookie: "c_ds_dispositivo_transjr_9430=#{'a' * 64}") }

  context 'with the right code' do
    before { allow(client).to receive(:confirm_device).and_return(device) }

    it 'stores the device in the tenant and confirms the registration' do
      session = registration.session

      described_class.call(registration, 'abc123', client:)

      expect(client).to have_received(:confirm_device).with(session, 'abc123')
      expect(tenant.reload).to have_attributes(atua_device_hash: 'a' * 64, atua_device_token: "c_ds_dispositivo_transjr_9430=#{'a' * 64}")
      expect(registration.reload).to have_attributes(status_type: 'confirmed', session_state: nil)
    end

    it 'keeps the stored cookie when the Atua does not send a new one' do
      tenant.update!(atua_device_token: 'c_ds_dispositivo_transjr_9430=old')
      allow(client).to receive(:confirm_device).and_return(device.with(device_cookie: nil))

      described_class.call(registration, 'abc123', client:)

      expect(tenant.reload).to have_attributes(atua_device_hash: 'a' * 64, atua_device_token: 'c_ds_dispositivo_transjr_9430=old')
    end

    it 'does nothing when the registration is already confirmed' do
      registration.confirm!

      expect(described_class.call(registration, 'abc123', client:)).to eq(registration)
      expect(client).not_to have_received(:confirm_device)
    end
  end

  context 'with a wrong code' do
    before { allow(client).to receive(:confirm_device).and_raise(Atua::DeviceVerificationError, 'Código inválido.') }

    it 'keeps the registration waiting for another try' do
      expect { described_class.call(registration, 'wrong1', client:) }.to raise_error(Atua::DeviceVerificationError, 'Código inválido.')

      expect(registration.reload).to have_attributes(status_type: 'code_sent')
      expect(tenant.reload.atua_device_hash).to be_nil
    end
  end

  context 'with an expired code' do
    let(:registration) { create(:atua_device_registration, tenant:, expires_at: 1.minute.ago) }

    it 'refuses to confirm it' do
      expect { described_class.call(registration, 'abc123', client:) }
        .to raise_error(Atua::DeviceVerificationError, 'O código de verificação expirou. Peça um novo código.')
    end
  end
end
