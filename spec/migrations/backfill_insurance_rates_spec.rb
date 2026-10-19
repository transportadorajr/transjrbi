require 'rails_helper'
require Rails.root.join('db/migrate/20261019144621_backfill_insurance_rates')

RSpec.describe BackfillInsuranceRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }

    it 'registers the default insurance rate of every tenant' do
      expect { migration.up }.to change(InsuranceRate, :count).by(2)

      expect(InsuranceRate.pluck(:tenant_id, :insurance_percentage, :iof_percentage)).to contain_exactly(
        [tenant.id, BigDecimal('0.022'), BigDecimal('7.38')], [other_tenant.id, BigDecimal('0.022'), BigDecimal('7.38')]
      )
    end

    it 'can run again without duplicating the rates' do
      migration.up

      expect { migration.up }.not_to change(InsuranceRate, :count)
    end
  end
end
