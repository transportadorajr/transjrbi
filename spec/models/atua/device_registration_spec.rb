require 'rails_helper'

RSpec.describe Atua::DeviceRegistration do
  describe 'validations' do
    it 'requires the expiration and a known status' do
      registration = described_class.new(tenant: build(:tenant), status_type: 'other')

      expect(registration).not_to be_valid
      expect(registration.errors.attribute_names).to contain_exactly(:expires_at, :status_type)
    end
  end

  describe '.pending' do
    let!(:pending) { create(:atua_device_registration) }

    before do
      create(:atua_device_registration, expires_at: 1.minute.ago)
      create(:atua_device_registration, status_type: 'confirmed')
    end

    it 'returns only the codes sent that did not expire' do
      expect(described_class.pending).to eq([pending])
    end
  end

  describe '#expired?' do
    it 'tells whether a sent code is past its expiration' do
      expect(build(:atua_device_registration, expires_at: 1.minute.ago)).to be_expired
      expect(build(:atua_device_registration)).not_to be_expired
      expect(build(:atua_device_registration, status_type: 'confirmed', expires_at: 1.minute.ago)).not_to be_expired
    end
  end

  describe '#session' do
    it 'reads the encrypted Atua session' do
      registration = create(:atua_device_registration)

      expect(registration.reload.session).to include('person_id' => '9430', 'cookies' => { 'PHPSESSID' => 'abc123' })
      expect(described_class.connection.select_value("SELECT session_state FROM atua_device_registrations WHERE id = #{registration.id}"))
        .not_to include('abc123')
    end

    it 'is empty without a session' do
      expect(build(:atua_device_registration, session_state: nil).session).to eq({})
    end
  end

  describe '#confirm!' do
    it 'marks the registration as confirmed and drops the session' do
      registration = create(:atua_device_registration)

      registration.confirm!

      expect(registration.reload).to have_attributes(status_type: 'confirmed', session_state: nil, error_message: nil)
      expect(registration.confirmed_at).to be_present
    end
  end

  describe '#fail!' do
    it 'keeps the error and drops the session' do
      registration = create(:atua_device_registration)

      registration.fail!('Código inválido.')

      expect(registration.reload).to have_attributes(status_type: 'failed', session_state: nil, error_message: 'Código inválido.')
    end
  end
end
