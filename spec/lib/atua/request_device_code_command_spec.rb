require 'rails_helper'

RSpec.describe Atua::RequestDeviceCodeCommand do
  let(:tenant) { create(:tenant) }
  let(:client) { instance_double(Atua::Client) }
  let(:state) { { 'cookies' => { 'PHPSESSID' => 'abc123' }, 'person_id' => '9430', 'masked_email' => 'int***@t***.test', 'form_fields' => {} } }

  context 'when the Atua sends the code' do
    before { allow(client).to receive(:request_device_code).and_return(state) }

    it 'creates a registration waiting for the code with the session encrypted' do
      registration = nil

      expect { registration = described_class.call(tenant, client:) }.to change(Atua::DeviceRegistration, :count).by(1)

      expect(registration).to have_attributes(tenant:, status_type: 'code_sent', masked_email: 'int***@t***.test')
      expect(registration.session).to eq(state)
      expect(registration.expires_at).to be_within(1.second).of(10.minutes.from_now)
    end

    it 'invalidates the code sent before when a new one is requested' do
      previous = create(:atua_device_registration, tenant:)

      described_class.call(tenant, client:)

      expect(previous.reload).to have_attributes(status_type: 'failed', session_state: nil)
      expect(tenant.atua_device_registrations.pending.count).to eq(1)
    end
  end

  context 'when the device is already trusted' do
    before { allow(client).to receive(:request_device_code).and_return(nil) }

    it 'returns nothing and keeps the registrations' do
      expect { expect(described_class.call(tenant, client:)).to be_nil }.not_to change(Atua::DeviceRegistration, :count)
    end
  end

  context 'when the Atua refuses the login' do
    before { allow(client).to receive(:request_device_code).and_raise(Atua::AuthenticationError, 'A Atua recusou o login.') }

    it 'raises the error without creating a registration' do
      expect { described_class.call(tenant, client:) }.to raise_error(Atua::AuthenticationError)
      expect(Atua::DeviceRegistration.count).to eq(0)
    end
  end
end
