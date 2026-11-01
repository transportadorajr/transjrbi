require 'rails_helper'

RSpec.describe Drivers::ExcludeCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }
  let!(:spare_vehicle) { create(:atua_vehicle, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA') }
  let!(:other_vehicle) { create(:atua_vehicle, tenant:, driver_code: 701, driver_name: 'ANA SOUZA') }
  let!(:stranger_vehicle) { create(:atua_vehicle, tenant: other_tenant, driver_code: 760, driver_name: 'JOSE DA SILVA') }
  let(:driver) { tenant.atua_vehicles.drivers.find_by!(driver_code: 760) }

  it 'records the exclusion and clears only that driver of the tenant from the vehicles' do
    expect { described_class.call(tenant, driver) }.to change(ExcludedDriver, :count).by(1)

    excluded_driver = ExcludedDriver.last
    expect(excluded_driver.tenant).to eq(tenant)
    expect(excluded_driver.code).to eq(760)
    expect(excluded_driver.name).to eq('JOSE DA SILVA')
    expect([vehicle.reload.driver_code, spare_vehicle.reload.driver_code]).to eq([nil, nil])
    expect(other_vehicle.reload.driver_code).to eq(701)
    expect(stranger_vehicle.reload.driver_code).to eq(760)
  end

  it 'returns the existing exclusion when it runs again' do
    first = described_class.call(tenant, driver)

    expect { expect(described_class.call(tenant, driver)).to eq(first) }.not_to change(ExcludedDriver, :count)
  end

  it 'keeps the transport documents of the driver' do
    transport_document = create(:atua_transport_document, tenant:, driver_code: 760, driver_name: 'JOSE DA SILVA')

    described_class.call(tenant, driver)

    expect(transport_document.reload.driver_name).to eq('JOSE DA SILVA')
  end
end
