require 'rails_helper'

RSpec.describe Atua::Vehicle do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with transport documents, manifests and expenses of the tenant' do
      let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
      let!(:trailer) { create(:atua_vehicle, tenant:, code: 813, plate: 'BEV4G50') }
      let!(:transport_document) { create(:atua_transport_document, tenant:, vehicle_code: 812, plate: 'EXU0F72', trailer_plate: 'BEV4G50') }
      let!(:manifest) { create(:atua_manifest, tenant:, plate: 'EXU0F72') }
      let!(:expense) { create(:atua_expense, tenant:, plate: 'EXU0F72', cost_object: truck) }
      let!(:freight_expense) { create(:atua_expense, tenant:, plate: 'EXU0F72', cost_object: transport_document) }

      before do
        other_truck = create(:atua_vehicle, tenant: other_tenant, code: 812, plate: 'EXU0F72')
        create(:atua_transport_document, tenant: other_tenant, vehicle_code: 812, trailer_plate: 'BEV4G50')
        create(:atua_manifest, tenant: other_tenant, plate: 'EXU0F72')
        create(:atua_expense, tenant: other_tenant, plate: 'EXU0F72', cost_object: other_truck)
      end

      it 'lists the transport documents pulled as truck or trailer inside the tenant' do
        expect(truck.transport_documents).to eq([transport_document])
        expect(trailer.trailer_transport_documents).to eq([transport_document])
        expect(trailer.transport_documents).to be_empty
      end

      it 'lists the manifests by plate inside the tenant' do
        expect(truck.manifests).to eq([manifest])
        expect(Atua::Manifest.count).to eq(2)
      end

      it 'lists the expenses linked directly to the vehicle' do
        expect(truck.direct_expenses).to eq([expense])
        expect(trailer.direct_expenses).to be_empty
      end

      it 'lists its own expenses and the expenses of the freights it pulled as truck or trailer' do
        expect(truck.expenses).to contain_exactly(expense, freight_expense)
        expect(trailer.expenses).to eq([freight_expense])
        expect(Atua::Expense.count).to eq(3)
      end
    end
  end

  describe 'validations' do
    context 'with a vehicle already imported' do
      let!(:vehicle) { create(:atua_vehicle, tenant:, code: 152) }

      it 'rejects the same code in the same tenant' do
        duplicated = build(:atua_vehicle, tenant:, code: 152)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:atua_vehicle, tenant: other_tenant, code: vehicle.code)).to be_valid
      end
    end
  end

  describe 'scopes' do
    context 'with vehicles of different plates' do
      let!(:truck) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
      let!(:removed) { create(:atua_vehicle, tenant:, plate: 'AGL9451', removed_from_atua_at: Time.current) }

      it 'filters by the normalized plate' do
        expect(described_class.by_plate('exu-0f72')).to eq([truck])
        expect(described_class.count).to eq(2)
      end

      it 'keeps out vehicles removed from Atua' do
        expect(described_class.active).to eq([truck])
        expect(described_class.removed_from_atua).to eq([removed])
      end
    end

    context 'with vehicles of different categories and ownerships' do
      let!(:own_truck) { create(:atua_vehicle, tenant:, category: 'Caminhão / Cavalo', ownership: 'Próprio') }
      let!(:third_party_trailer) { create(:atua_vehicle, tenant:, category: 'Carreta', ownership: 'Terceiro') }

      it 'filters by category and ownership' do
        expect(described_class.by_category('Carreta')).to eq([third_party_trailer])
        expect(described_class.by_ownership('Próprio')).to eq([own_truck])
        expect(described_class.count).to eq(2)
      end
    end

    context 'with drivers linked to the vehicles' do
      let!(:truck) do
        create(:atua_vehicle, tenant:, plate: 'EXU0F72', driver_code: 760, driver_name: 'JOSE DA SILVA', driver_document: '808.542.250-64',
                              driver_document_digits: '80854225064', driver_license: '604269044')
      end
      let!(:spare_truck) { create(:atua_vehicle, tenant:, plate: 'AGL9451', driver_code: 760, driver_name: 'JOSE DA SILVA') }
      let!(:other_truck) { create(:atua_vehicle, tenant:, plate: 'RHJ4E07', driver_code: 701, driver_name: 'MARIA SOUZA') }

      before do
        create(:atua_vehicle, tenant:, plate: 'BEV4G50', driver_code: nil)
        create(:atua_vehicle, tenant:, plate: 'QQI0395', driver_code: 701, removed_from_atua_at: Time.current)
        create(:atua_vehicle, tenant: other_tenant, plate: 'ZIZ7D35', driver_code: 760, driver_name: 'JOSE DA SILVA')
      end

      it 'groups the active vehicles of the tenant by driver' do
        drivers = tenant.atua_vehicles.drivers.order(:driver_code)

        expect(drivers.count).to eq(2)
        expect(drivers.map { |driver| [driver.driver_code, driver.driver_name, driver.vehicles_count, driver.plates] }).to eq(
          [[701, 'MARIA SOUZA', 1, 'RHJ4E07'], [760, 'JOSE DA SILVA', 2, 'AGL9451, EXU0F72']],
        )
        expect(drivers.last.driver_document).to eq('808.542.250-64')
        expect(drivers.last.driver_license).to eq('604269044')
      end

      it 'filters the drivers by name and document' do
        expect(tenant.atua_vehicles.drivers.by_driver_name('maria').map(&:driver_code)).to eq([701])
        expect(tenant.atua_vehicles.drivers.by_driver_document('808.542.250-64').map(&:driver_code)).to eq([760])
      end
    end
  end
end
