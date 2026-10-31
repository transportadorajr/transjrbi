require 'rails_helper'

RSpec.describe Atua::PurgeInactiveDriversCommand do
  let(:tenant) { create(:tenant) }
  let!(:inactive_vehicle) do
    create(:atua_vehicle, tenant:, driver_code: 1, driver_name: 'INATIVO', driver_document: '111', driver_document_digits: '111',
                          driver_license: '222', driver_whatsapp_at: Time.current,
                          raw_data: { 'cd_motorista' => 1, 'nm_motorista' => 'INATIVO', 'ds_placa' => 'AAA1234' })
  end
  let!(:active_vehicle) { create(:atua_vehicle, tenant:, driver_code: 2, driver_name: 'ATIVO') }

  context 'when the tenant has no transport documents loaded' do
    it 'keeps every driver' do
      expect(described_class.call(tenant)).to eq(0)
      expect(inactive_vehicle.reload.driver_code).to eq(1)
    end
  end

  context 'when a driver only has a transport document older than twelve months' do
    before do
      create(:atua_transport_document, tenant:, driver_code: 1, issued_at: 13.months.ago)
      create(:atua_transport_document, tenant:, driver_code: 2, issued_at: 1.month.ago)
    end

    it 'clears the driver from the vehicle, keeps the vehicle and can run again' do
      expect(described_class.call(tenant)).to eq(1)

      inactive_vehicle.reload
      expect(inactive_vehicle.attributes.values_at('driver_code', 'driver_name', 'driver_document', 'driver_document_digits', 'driver_license', 'driver_whatsapp_at').compact).to eq([])
      expect(inactive_vehicle.raw_data).to eq('ds_placa' => 'AAA1234')
      expect(active_vehicle.reload.driver_code).to eq(2)
      expect(tenant.atua_vehicles.drivers.map(&:driver_code)).to eq([2])
      expect(described_class.call(tenant)).to eq(0)
    end
  end
end
