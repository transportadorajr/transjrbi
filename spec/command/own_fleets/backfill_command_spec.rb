require 'rails_helper'

RSpec.describe OwnFleets::BackfillCommand do
  context 'with a tenant without an own fleet' do
    let!(:tenant) { create(:tenant) }

    it 'registers the default plates of the own fleet' do
      expect { described_class.call(tenant) }.to change(OwnFleet, :count).by(1)

      plates = tenant.reload.own_fleet.plates
      expect(plates.size).to eq(127)
      expect(plates.first(3)).to eq(%w[AJR4391 ALC6D72 AQZ1D12])
      expect(plates).to include('RHJ4A01', 'UBN0J40')
    end

    it 'can run again without changing the plates' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change { tenant.reload.own_fleet.updated_at }
    end
  end

  context 'with a tenant whose own fleet has no plates' do
    let!(:tenant) { create(:tenant) }
    let!(:own_fleet) { OwnFleet.create!(tenant:, plates: []) }

    it 'fills the plates of the existing own fleet' do
      expect { described_class.call(tenant) }.not_to change(OwnFleet, :count)

      expect(own_fleet.reload.plates.size).to eq(127)
    end
  end

  context 'with a tenant that already registered its plates' do
    let!(:tenant) { create(:tenant) }
    let!(:own_fleet) { OwnFleet.create!(tenant:, plates: %w[ABC1D23]) }

    it 'keeps the plates the tenant registered' do
      described_class.call(tenant)

      expect(own_fleet.reload.plates).to eq(%w[ABC1D23])
    end
  end
end
