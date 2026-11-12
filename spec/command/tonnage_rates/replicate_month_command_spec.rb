require 'rails_helper'

RSpec.describe TonnageRates::ReplicateMonthCommand do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let(:november) { Date.new(2026, 11, 1) }

  context 'when the tenant has active rates of the previous months' do
    let!(:cubatao_september) do
      create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 9, 1), rate_cents: 1_190)
    end
    let!(:cubatao_october) { create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 10, 1)) }
    let!(:ipatinga) do
      create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: nil, origin_city: 'Ipatinga', origin_state: 'MG',
                            valid_month: Date.new(2026, 8, 1), rate_cents: 860)
    end

    it 'copies the latest rate of each origin into the new month with the same values' do
      copies = nil

      expect { copies = described_class.call(tenant, Date.new(2026, 11, 12)) }.to change(TonnageRate, :count).by(2)

      expect(copies.map { |copy| copy.slice(:name, :nickname, :origin_city, :origin_state, :rate_cents, :valid_month) }).to contain_exactly(
        { 'name' => 'Brasiltec', 'nickname' => 'Cubatão', 'origin_city' => 'Cubatão', 'origin_state' => 'SP', 'rate_cents' => 1_257,
          'valid_month' => november },
        { 'name' => 'Brasiltec', 'nickname' => nil, 'origin_city' => 'Ipatinga', 'origin_state' => 'MG', 'rate_cents' => 860,
          'valid_month' => november },
      )
      expect(copies.map(&:copied_from)).to contain_exactly(cubatao_october, ipatinga)
      expect(copies).to all(be_activated)
      expect(copies).to all(be_pending_review)
      expect(copies.map(&:customer_group)).to all(eq(usiminas))
    end

    it 'does not copy the rates twice' do
      described_class.call(tenant, november)

      expect { described_class.call(tenant, november) }.not_to change(TonnageRate, :count)
    end

    it 'keeps the rate the logistics team already registered for the month' do
      create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: november, rate_cents: 1_300)

      copies = described_class.call(tenant, november)

      expect(copies.map(&:origin_city)).to eq(['Ipatinga'])
      expect(tenant.tonnage_rates.where(valid_month: november, origin_city: 'Cubatão').pluck(:rate_cents)).to eq([1_300])
    end

    it 'does not copy into the month an origin with a deactivated rate in it' do
      create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: november, activated_at: nil)

      expect(described_class.call(tenant, november).map(&:origin_city)).to eq(['Ipatinga'])
    end
  end

  it 'does not copy a deactivated rate' do
    create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 10, 1), activated_at: nil)

    expect(described_class.call(tenant, november)).to eq([])
  end

  it 'does not copy the rates of another tenant' do
    other_tenant = create(:tenant)
    create(:tonnage_rate, tenant: other_tenant, customer_group: create(:customer_group, tenant: other_tenant))

    expect { described_class.call(tenant, november) }.not_to change(TonnageRate, :count)
  end
end
