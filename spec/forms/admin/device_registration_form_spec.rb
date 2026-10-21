require 'rails_helper'

RSpec.describe Admin::DeviceRegistrationForm do
  let(:tenant) { create(:tenant) }
  let(:registration) { create(:atua_device_registration, tenant:) }

  describe 'validations' do
    it 'requires a code with 4 to 10 letters or digits' do
      %w[ABC 12345678901 AB-12].each do |code|
        form = described_class.new(tenant_id: tenant.id, registration_id: registration.id, code:)

        expect(form).not_to be_valid
        expect(form.errors.attribute_names).to eq([:code])
      end
    end

    it 'requires a registration of the tenant' do
      form = described_class.new(tenant_id: tenant.id, registration_id: create(:atua_device_registration).id, code: 'ABC123')

      expect(form).not_to be_valid
      expect(form.errors.attribute_names).to eq([:pending_registration])
    end
  end

  describe '#save' do
    it 'confirms the device with the code' do
      allow(Atua::ConfirmDeviceCommand).to receive(:call).and_return(registration)

      form = described_class.new(tenant_id: tenant.id, registration_id: registration.id, code: 'ABC123')

      expect(form.save).to be(true)
      expect(Atua::ConfirmDeviceCommand).to have_received(:call).with(registration, 'ABC123')
    end

    it 'shows the message of the Atua when the code is refused' do
      allow(Atua::ConfirmDeviceCommand).to receive(:call).and_raise(Atua::DeviceVerificationError, 'Código inválido.')

      form = described_class.new(tenant_id: tenant.id, registration_id: registration.id, code: 'ABC123')

      expect(form.save).to be(false)
      expect(form.errors.full_messages).to eq(['Código inválido.'])
    end
  end

  describe '#request_code' do
    it 'returns the registration created for the code sent' do
      allow(Atua::RequestDeviceCodeCommand).to receive(:call).and_return(registration)

      expect(described_class.new(tenant_id: tenant.id).request_code).to eq(registration)
      expect(Atua::RequestDeviceCodeCommand).to have_received(:call).with(tenant)
    end

    it 'keeps the error when the Atua refuses the login' do
      allow(Atua::RequestDeviceCodeCommand).to receive(:call).and_raise(Atua::AuthenticationError, 'A Atua recusou o login.')
      form = described_class.new(tenant_id: tenant.id)

      expect(form.request_code).to be_nil
      expect(form.errors.full_messages).to eq(['A Atua recusou o login.'])
    end
  end
end
