require 'rails_helper'

RSpec.describe TonnageRates::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'with the Usiminas group' do
    let!(:group) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 501, customer_group: group) }
    let!(:document) do
      create(:atua_transport_document, tenant:, taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       issued_at: Time.zone.local(2026, 9, 20, 8), weight_tons: BigDecimal('32.5'))
    end

    it 'registers the Brasiltec rates of the skill and calculates the costs' do
      expect { described_class.call(tenant) }.to change(TonnageRate, :count).by(4)

      expect(group.tonnage_rates.order(:id).pluck(:name, :nickname, :origin_city, :origin_state, :valid_month, :rate_cents)).to eq(
        [
          ['Brasiltec', 'Cubatão', 'Cubatão', 'SP', Date.new(2026, 10, 1), 1_257],
          ['Brasiltec', 'Utinga', 'Santo André', 'SP', Date.new(2026, 10, 1), 1_802],
          ['Brasiltec', 'Ipatinga', 'Ipatinga', 'MG', Date.new(2026, 10, 1), 860],
          ['Brasiltec', 'TESP', 'São Paulo', 'SP', Date.new(2026, 10, 1), 880],
        ],
      )
      expect(group.tonnage_rates).to all(be_activated)
      expect(FreightExpense.tonnage.sole).to have_attributes(transport_document: document, amount_cents: 40_853)
    end

    it 'can run again without duplicating the rates' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change(TonnageRate, :count)
    end

    context 'when the group already has rates' do
      let!(:rate) { create(:tonnage_rate, tenant:, customer_group: group, rate_cents: 1_300) }

      it 'keeps the rates registered by the users' do
        expect { described_class.call(tenant) }.not_to change(TonnageRate, :count)

        expect(rate.reload.rate_cents).to eq(1_300)
      end
    end
  end

  context 'without the Usiminas group' do
    it 'does not register any rate' do
      expect(described_class.call(tenant)).to eq([])
      expect(TonnageRate.count).to eq(0)
    end
  end
end
