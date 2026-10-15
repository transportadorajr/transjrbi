require 'rails_helper'

RSpec.describe Atua::LinkExpensesCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with expenses of freights, vehicles and the overhead' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, vehicle_code: 812) }
    let!(:toll) { create(:atua_expense, tenant:, transport_document_code: 80_512, plate: 'EXU0F72') }
    let!(:tire) { create(:atua_expense, tenant:, plate: 'EXU0F72') }
    let!(:rent) { create(:atua_expense, tenant:, plate: nil) }
    let!(:unknown_plate) { create(:atua_expense, tenant:, plate: 'ZZZ9Z99') }

    it 'links each expense to its freight, falling back to the vehicle of its plate' do
      expect(described_class.call(tenant)).to eq(2)

      expect(toll.reload.cost_object).to eq(transport_document)
      expect(tire.reload.cost_object).to eq(truck)
      expect(rent.reload.cost_object).to be_nil
      expect(unknown_plate.reload.cost_object).to be_nil
    end

    it 'does not touch the expenses again when nothing changed' do
      described_class.call(tenant)

      expect { expect(described_class.call(tenant)).to eq(0) }.not_to(change { toll.reload.updated_at })
    end
  end

  context 'when the freight of an expense is imported after the expense was linked to the vehicle' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:toll) { create(:atua_expense, tenant:, transport_document_code: 80_512, plate: 'EXU0F72', cost_object: truck) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, vehicle_code: 812) }

    it 'moves the expense from the vehicle to the freight' do
      described_class.call(tenant)

      expect(toll.reload.cost_object).to eq(transport_document)
    end
  end

  context 'when the freight of an expense was removed from Atua' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512) }
    let!(:toll) { create(:atua_expense, tenant:, transport_document_code: 80_512, plate: 'EXU0F72', cost_object: transport_document) }

    before { transport_document.update!(removed_from_atua_at: Time.current) }

    it 'moves the expense back to the vehicle of its plate' do
      described_class.call(tenant)

      expect(toll.reload.cost_object).to eq(truck)
    end
  end

  context 'with two registrations of the same plate' do
    let!(:old_truck) { create(:atua_vehicle, tenant:, code: 700, plate: 'EXU0F72', removed_from_atua_at: Time.current) }
    let!(:truck) { create(:atua_vehicle, tenant:, code: 600, plate: 'EXU0F72') }
    let!(:tire) { create(:atua_expense, tenant:, plate: 'EXU0F72') }

    it 'prefers the registration still active in Atua' do
      described_class.call(tenant)

      expect(tire.reload.cost_object).to eq(truck)
    end
  end

  context 'with a vehicle removed from Atua' do
    let!(:truck) { create(:atua_vehicle, tenant:, plate: 'EXU0F72', removed_from_atua_at: Time.current) }
    let!(:tire) { create(:atua_expense, tenant:, plate: 'EXU0F72') }

    it 'still links the expense to the vehicle of its plate' do
      described_class.call(tenant)

      expect(tire.reload.cost_object).to eq(truck)
    end
  end

  context 'with records of another tenant' do
    let!(:tire) { create(:atua_expense, tenant:, transport_document_code: 80_512, plate: 'EXU0F72') }
    let!(:stranger) { create(:atua_expense, tenant: other_tenant, plate: 'EXU0F72') }

    before do
      create(:atua_transport_document, tenant: other_tenant, code: 80_512)
      create(:atua_vehicle, tenant: other_tenant, plate: 'EXU0F72')
    end

    it 'links only the expenses of the tenant to records of the same tenant' do
      expect(described_class.call(tenant)).to eq(0)

      expect(tire.reload.cost_object).to be_nil
      expect(stranger.reload.cost_object).to be_nil
    end
  end
end
