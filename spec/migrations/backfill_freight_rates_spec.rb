require 'rails_helper'
require Rails.root.join('db/migrate/20261028200936_backfill_freight_rates')

RSpec.describe BackfillFreightRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a tenant without rates and a Usiminas transport document' do
    let!(:tenant) { create(:tenant) }
    let!(:customer) { create(:atua_customer, tenant:, code: 501, name: 'USIMINAS CUBATAO') }
    let!(:document) do
      create(:atua_transport_document, tenant:, taker_code: 501, origin_city: 'CUBATAO', origin_state: 'SP',
                                       destination_city: 'IPATINGA', destination_state: 'MG', freight_cents: 1_000_000,
                                       icms_cents: 120_000, goods_value_cents: 838_998, weight_tons: BigDecimal('1.917'))
    end

    it 'registers the commission rules, the Brasiltec rates and the insurance rate' do
      migration.up

      expect(tenant.commission_rules.order(:id).pluck(:name, :destination_type, :base_type, :percentage)).to eq(
        [
          ['Nacional', 'national', 'freight_without_icms', BigDecimal('2.0')],
          ['Argentina', 'foreign', 'freight', BigDecimal('1.3')],
          ['Paraguai', 'foreign', 'freight', BigDecimal('1.5')],
        ],
      )
      expect(tenant.tonnage_rates.order(:id).pluck(:nickname, :origin_city, :origin_state, :rate_cents, :valid_month)).to eq(
        [
          ['Cubatão', 'Cubatão', 'SP', 1_257, Date.new(2026, 10, 1)],
          ['Utinga', 'Santo André', 'SP', 1_802, Date.new(2026, 10, 1)],
          ['Ipatinga', 'Ipatinga', 'MG', 860, Date.new(2026, 10, 1)],
          ['TESP', 'São Paulo', 'SP', 880, Date.new(2026, 10, 1)],
        ],
      )
      expect(tenant.insurance_rate.reload).to have_attributes(insurance_percentage: BigDecimal('0.022'), iof_percentage: BigDecimal('7.38'))
    end

    it 'recalculates the freight expenses of the transport document' do
      manifest = create(:atua_manifest, tenant:)
      create(:atua_transport_document_manifest, tenant:, transport_document_code: document.code, manifest_number: manifest.number,
                                                branch_name: manifest.branch_name)
      migration.up

      expenses = tenant.freight_expenses.where(transport_document: document).index_by(&:kind_type)

      expect(expenses.keys).to contain_exactly('commission', 'tonnage', 'insurance')
      expect(expenses['commission']).to have_attributes(base_cents: 880_000, amount_cents: 17_600)
      expect(expenses['tonnage']).to have_attributes(weight_tons: BigDecimal('1.917'), rate_cents: 1_257, amount_cents: 2_410)
      expect(expenses['insurance']).to have_attributes(insurance_rate: tenant.insurance_rate, base_cents: 1_838_998)
    end

    it 'can run again without duplicating the rates or the expenses' do
      migration.up

      expect { migration.up }.not_to change { [CommissionRule.count, TonnageRate.count, InsuranceRate.count, FreightExpense.count] }
    end
  end

  context 'with a tenant whose rates were changed on the screens' do
    let!(:tenant) { create(:tenant) }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: usiminas, percentage: BigDecimal('2.5')) }
    let!(:tonnage_rate) { create(:tonnage_rate, tenant:, customer_group: usiminas, rate_cents: 1_400) }
    let!(:insurance_rate) { create(:insurance_rate, tenant:, insurance_percentage: BigDecimal('0.03')) }

    it 'keeps the values the tenant already has' do
      expect { migration.up }.not_to change { [CommissionRule.count, TonnageRate.count, InsuranceRate.count] }

      expect(commission_rule.reload.percentage).to eq(BigDecimal('2.5'))
      expect(tonnage_rate.reload.rate_cents).to eq(1_400)
      expect(insurance_rate.reload.insurance_percentage).to eq(BigDecimal('0.03'))
    end
  end
end
