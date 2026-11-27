require 'rails_helper'

RSpec.describe FleetProductivityFilterForm do
  around { |example| travel_to(Date.new(2026, 10, 19)) { example.run } }

  context 'without filters' do
    it 'defaults to the current week from sunday to saturday' do
      form = described_class.new

      expect(form).to be_valid
      expect(form.period).to eq(Date.new(2026, 10, 18)..Date.new(2026, 10, 24))
      expect(form).not_to be_filtered
    end
  end

  context 'with filters' do
    it 'is filtered by another period, the plate or the customer group' do
      expect(described_class.new(start_date: '2026-10-01', end_date: '2026-10-31')).to be_filtered
      expect(described_class.new(plate: 'RVR2C34')).to be_filtered
      expect(described_class.new(customer_group_id: '7')).to be_filtered
    end
  end

  context 'when the period ends before it starts' do
    it 'is invalid' do
      form = described_class.new(start_date: '2026-10-31', end_date: '2026-10-01')

      expect(form).not_to be_valid
      expect(form.errors.full_messages).to eq(['Viagens até não pode ser anterior à data inicial'])
    end
  end

  describe '#apply' do
    let!(:tenant) { create(:tenant) }
    let!(:coamo) { create(:customer_group, tenant:, name: 'COAMO') }
    let!(:in_period) { create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_100) }
    let!(:other_plate) { create(:empty_leg, tenant:, plate: 'RVR8J90', next_manifest_code: 41_200) }
    let!(:out_of_period) { create(:empty_leg, tenant:, plate: 'RVR2C34', next_manifest_code: 41_300) }

    before do
      create(:atua_manifest, tenant:, code: 41_100, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 10, 5, 8))
      create(:atua_manifest, tenant:, code: 41_200, plate: 'RVR8J90', trip_started_at: Time.zone.local(2026, 10, 6, 8))
      create(:atua_manifest, tenant:, code: 41_300, plate: 'RVR2C34', trip_started_at: Time.zone.local(2026, 9, 5, 8))
      create(:atua_customer, tenant:, code: 7501, customer_group: coamo)
      create(:atua_transport_document, tenant:, code: 90_001, taker_code: 7501)
      create(:empty_leg_transport_document, empty_leg: other_plate, transport_document_code: 90_001)
    end

    it 'keeps the empty legs of the trips started in the period' do
      form = described_class.new(start_date: '2026-10-01', end_date: '2026-10-31')

      expect(form.apply(tenant.empty_legs)).to contain_exactly(in_period, other_plate)
    end

    it 'keeps the empty legs of the plate' do
      form = described_class.new(start_date: '2026-10-01', end_date: '2026-10-31', plate: 'rvr2c34')

      expect(form.apply(tenant.empty_legs)).to contain_exactly(in_period)
    end

    it 'keeps the empty legs of the next load of the customer group' do
      form = described_class.new(start_date: '2026-10-01', end_date: '2026-10-31', customer_group_id: coamo.id)

      expect(form.apply(tenant.empty_legs)).to contain_exactly(other_plate)
    end
  end
end
