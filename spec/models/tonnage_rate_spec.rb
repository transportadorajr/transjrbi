require 'rails_helper'

RSpec.describe TonnageRate do
  let(:tenant) { create(:tenant) }
  let(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }

  describe 'validations' do
    it 'requires the name, the origin, the month and a positive rate' do
      rate = described_class.new(tenant:, customer_group: usiminas, rate_cents: 0)

      expect(rate).not_to be_valid
      expect(rate.errors.attribute_names).to contain_exactly(:name, :origin_city, :origin_state, :valid_month, :rate_cents)
    end
  end

  describe '.weight_in_tons' do
    it 'keeps a weight up to 200 as tons' do
      expect(described_class.weight_in_tons(BigDecimal('32.5'), nil)).to eq(BigDecimal('32.5'))
      expect(described_class.weight_in_tons(BigDecimal('200'), nil)).to eq(BigDecimal('200'))
    end

    it 'converts a weight above 200 from kilograms' do
      expect(described_class.weight_in_tons(BigDecimal('32500'), nil)).to eq(BigDecimal('32.5'))
    end

    it 'falls back to the weight in kilograms' do
      expect(described_class.weight_in_tons(nil, BigDecimal('27150'))).to eq(BigDecimal('27.15'))
    end

    it 'returns nothing without a weight' do
      expect(described_class.weight_in_tons(nil, nil)).to be_nil
      expect(described_class.weight_in_tons(0, 0)).to be_nil
    end
  end

  describe '.for_month' do
    let(:september) { build(:tonnage_rate, valid_month: Date.new(2026, 9, 1)) }
    let(:october) { build(:tonnage_rate, valid_month: Date.new(2026, 10, 1)) }

    it 'uses the rate of the month of the transport document' do
      expect(described_class.for_month([september, october], Date.new(2026, 10, 1))).to eq(october)
    end

    it 'uses the previous month while the month has no rate' do
      expect(described_class.for_month([september, october], Date.new(2026, 11, 1))).to eq(october)
    end

    it 'uses the first rate for a transport document older than every rate' do
      expect(described_class.for_month([october, september], Date.new(2026, 8, 1))).to eq(september)
    end
  end

  describe '.parse_month' do
    it 'reads the month of a month field' do
      expect(described_class.parse_month('2026-10')).to eq(Date.new(2026, 10, 1))
    end

    it 'ignores an invalid month' do
      expect(described_class.parse_month('outubro')).to be_nil
    end
  end

  describe '#amount_cents' do
    it 'multiplies the weight by the rate rounding half up' do
      expect(build(:tonnage_rate, rate_cents: 1_257).amount_cents(BigDecimal('32.5'))).to eq(40_853)
    end
  end

  describe '#reference_month' do
    it 'is the month before the valid month' do
      expect(build(:tonnage_rate, valid_month: Date.new(2026, 10, 1)).reference_month).to eq(Date.new(2026, 9, 1))
    end
  end

  describe 'scopes' do
    let!(:october) { create(:tonnage_rate, tenant:, customer_group: usiminas) }
    let!(:september) do
      create(:tonnage_rate, tenant:, customer_group: usiminas, name: 'Outro custo', valid_month: Date.new(2026, 9, 1), activated_at: nil)
    end

    it 'filters by name, month and status' do
      expect(described_class.by_name('brasil')).to contain_exactly(october)
      expect(described_class.by_valid_month('2026-09')).to contain_exactly(september)
      expect(described_class.by_status('active')).to contain_exactly(october)
      expect(described_class.by_status('deactivated')).to contain_exactly(september)
    end
  end

  describe '.missing_weight_documents' do
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, customer_group: usiminas) }
    let!(:rate) { create(:tonnage_rate, tenant:, customer_group: usiminas) }
    let!(:without_weight) do
      create(:atua_transport_document, tenant:, number: '1', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       weight_tons: nil, weight_kg: nil)
    end
    let!(:weighed) do
      create(:atua_transport_document, tenant:, number: '2', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP', weight_tons: 10)
    end
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '3', taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issue_kind: 'Complemento de Valores', weight_tons: nil, weight_kg: nil)
    end
    let!(:other_origin) do
      create(:atua_transport_document, tenant:, number: '4', taker_code: 501, origin_city: 'BETIM', origin_state: 'MG',
                                       weight_tons: nil, weight_kg: nil)
    end

    it 'lists the transport documents of an origin with cost that came without weight, except value complements' do
      expect(described_class.missing_weight_documents(tenant)).to contain_exactly(without_weight)
    end
  end

  describe '.outdated' do
    before { travel_to Time.zone.local(2026, 10, 16, 12) }

    let!(:current) { create(:tonnage_rate, tenant:, customer_group: usiminas, valid_month: Date.new(2026, 9, 1)) }
    let!(:old) do
      create(:tonnage_rate, tenant:, customer_group: usiminas, origin_city: 'Ipatinga', origin_state: 'MG', valid_month: Date.new(2026, 8, 1))
    end

    it 'lists the origins whose latest month is more than two months old' do
      expect(described_class.outdated(tenant)).to eq([old])
    end
  end
end
