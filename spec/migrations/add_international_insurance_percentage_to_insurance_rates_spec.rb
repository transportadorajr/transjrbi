require 'rails_helper'
require Rails.root.join('db/migrate/20261104171511_add_international_insurance_percentage_to_insurance_rates')

RSpec.describe AddInternationalInsurancePercentageToInsuranceRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  after { InsuranceRate.reset_column_information }

  context 'when a tenant already has a rate' do
    let!(:tenant) { create(:tenant) }

    before do
      migration.down
      InsuranceRate.reset_column_information
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO insurance_rates (tenant_id, insurance_percentage, iof_percentage, created_at, updated_at)
        VALUES (#{tenant.id}, 0.022, 7.38, NOW(), NOW())
      SQL
    end

    it 'fills the international rate with the rate of the international policy' do
      migration.up
      InsuranceRate.reset_column_information

      expect(InsuranceRate.find_by!(tenant:)).to have_attributes(
        insurance_percentage: BigDecimal('0.022'), international_insurance_percentage: BigDecimal('0.065'), iof_percentage: BigDecimal('7.38'),
      )
    end
  end
end
