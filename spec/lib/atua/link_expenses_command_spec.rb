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

  context 'with unloading expenses that carry only the number of the freight' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_512, number: '74158', series: 1) }
    let!(:unload) { create(:atua_expense, tenant:, history_code: 72, transport_document_number: '74158', plate: 'EXU0F72') }
    let!(:damage) do
      create(:atua_expense, tenant:, history_code: 474, transport_document_number: '74158', transport_document_series: 1)
    end
    let!(:unknown_number) { create(:atua_expense, tenant:, history_code: 72, transport_document_number: '99999', plate: 'EXU0F72') }

    it 'links the expenses to the freight of the number, falling back to the vehicle of its plate' do
      expect(described_class.call(tenant)).to eq(3)

      expect(unload.reload.cost_object).to eq(transport_document)
      expect(damage.reload.cost_object).to eq(transport_document)
      expect(unknown_number.reload.cost_object).to eq(truck)
    end
  end

  context 'when an expense carries the code of one freight and the number of another' do
    let!(:coded) { create(:atua_transport_document, tenant:, code: 80_512, number: '74158') }
    let!(:numbered) { create(:atua_transport_document, tenant:, code: 80_513, number: '74159') }
    let!(:unload) { create(:atua_expense, tenant:, transport_document_code: 80_512, transport_document_number: '74159') }

    it 'prefers the freight of the code' do
      described_class.call(tenant)

      expect(unload.reload.cost_object).to eq(coded)
      expect(numbered.expenses).to be_empty
    end
  end

  context 'with several freights of the same number' do
    let!(:recent_cte) do
      create(:atua_transport_document, tenant:, code: 80_510, number: '74158', document_kind: 'cte', plate: 'BEV4G50',
                                       issued_at: Time.zone.local(2026, 10, 5, 8))
    end
    let!(:truck_cte) { create(:atua_transport_document, tenant:, code: 80_511, number: '74158', document_kind: 'cte', plate: 'EXU0F72') }
    let!(:canceled_cte) do
      create(:atua_transport_document, tenant:, code: 80_512, number: '74158', document_kind: 'cte', plate: 'EXU0F72',
                                       canceled_at: Time.current)
    end
    let!(:removed_cte) do
      create(:atua_transport_document, tenant:, code: 80_513, number: '74158', document_kind: 'cte', plate: 'EXU0F72',
                                       removed_from_atua_at: Time.current)
    end
    let!(:ce) { create(:atua_transport_document, tenant:, code: 80_514, number: '74158', document_kind: 'ce', plate: 'EXU0F72') }
    let!(:unload) { create(:atua_expense, tenant:, history_code: 72, transport_document_number: '74158', plate: 'EXU0F72') }
    let!(:other_unload) { create(:atua_expense, tenant:, history_code: 72, transport_document_number: '74158', plate: 'ZZZ9Z99') }

    it 'prefers the valid CT-e still in Atua carried by the plate of the expense, then the most recent one' do
      described_class.call(tenant)

      expect(unload.reload.cost_object).to eq(truck_cte)
      expect(other_unload.reload.cost_object).to eq(recent_cte)
      expect([canceled_cte, removed_cte, ce].flat_map(&:expenses)).to be_empty
    end
  end

  context 'when the freight of an unloading expense is imported after the expense' do
    let!(:truck) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
    let!(:unload) do
      create(:atua_expense, tenant:, history_code: 72, transport_document_number: '74158', plate: 'EXU0F72', cost_object: truck)
    end

    before { create(:atua_transport_document, tenant:, code: 80_512, number: '74158') }

    it 'moves the expense from the vehicle to the freight' do
      described_class.call(tenant)

      expect(unload.reload.cost_object).to eq(Atua::TransportDocument.find_by(code: 80_512))
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
