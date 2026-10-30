require 'rails_helper'
require Rails.root.join('db/migrate/20261019163831_remove_valid_from_from_insurance_rates')

RSpec.describe RemoveValidFromFromInsuranceRates do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  around { |example| travel_to(Time.zone.local(2026, 10, 19, 12)) { example.run } }

  after { InsuranceRate.reset_column_information }

  context 'when a tenant has rates of several validities' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }
    let!(:document) do
      create(:atua_transport_document, tenant:, goods_value_cents: 838_998, freight_cents: 55_504, destination_state: 'MG')
    end

    before do
      manifest = create(:atua_manifest, tenant:)
      create(:atua_transport_document_manifest, tenant:, transport_document_code: document.code, manifest_number: manifest.number,
                                                branch_name: manifest.branch_name)
      migration.down
      InsuranceRate.reset_column_information
    end

    it 'keeps the rate in force today and recalculates the insurance with it' do
      september = insert_rate(tenant, '2026-09-01', '0.02')
      october = insert_rate(tenant, '2026-10-01', '0.022')
      insert_rate(tenant, '2026-12-01', '0.03')
      other_rate = insert_rate(other_tenant, '2026-12-01', '0.022')
      expense = create(:freight_expense, :insurance, tenant:, transport_document: document, insurance_rate_id: september,
                                                     base_cents: 894_502, percentage: BigDecimal('0.02'), amount_cents: 179)

      migration.up
      InsuranceRate.reset_column_information

      expect(InsuranceRate.column_names).not_to include('valid_from')
      expect(InsuranceRate.pluck(:id)).to contain_exactly(october, other_rate)
      expect(expense.reload).to have_attributes(insurance_rate_id: october, percentage: BigDecimal('0.022'), amount_cents: 197)
    end
  end

  def insert_rate(tenant, valid_from, percentage)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      INSERT INTO insurance_rates (tenant_id, valid_from, insurance_percentage, iof_percentage, created_at, updated_at)
      VALUES (#{tenant.id}, '#{valid_from}', #{percentage}, 7.38, NOW(), NOW()) RETURNING id
    SQL
  end
end
