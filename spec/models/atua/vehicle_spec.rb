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
      let!(:expense) { create(:atua_expense, tenant:, plate: 'EXU0F72') }

      before do
        create(:atua_transport_document, tenant: other_tenant, vehicle_code: 812, trailer_plate: 'BEV4G50')
        create(:atua_manifest, tenant: other_tenant, plate: 'EXU0F72')
        create(:atua_expense, tenant: other_tenant, plate: 'EXU0F72')
      end

      it 'lists the transport documents pulled as truck or trailer inside the tenant' do
        expect(truck.transport_documents).to eq([transport_document])
        expect(trailer.trailer_transport_documents).to eq([transport_document])
        expect(trailer.transport_documents).to be_empty
      end

      it 'lists the manifests and expenses by plate inside the tenant' do
        expect(truck.manifests).to eq([manifest])
        expect(truck.expenses).to eq([expense])
        expect(Atua::Manifest.count).to eq(2)
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
  end
end
