require 'rails_helper'
require Rails.root.join('db/migrate/20261104183622_recalculate_insurance_of_export_cargo')

RSpec.describe RecalculateInsuranceOfExportCargo do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with the insurance of an export cargo calculated before the international insurance' do
    let!(:tenant) { create(:tenant) }
    let!(:rate) { create(:insurance_rate, tenant:) }
    let!(:national) { create(:atua_transport_document, tenant:, number: '76001', goods_value_cents: 1_000_000, destination_state: 'MG') }
    let!(:export) do
      create(:atua_transport_document, tenant:, number: '76002', goods_value_cents: 1_000_000, destination_state: 'PR',
                                       cargo_destination_type: 'export')
    end

    before do
      [national, export].each do |document|
        manifest = create(:atua_manifest, tenant:)
        create(:atua_transport_document_manifest, tenant:, transport_document_code: document.code, manifest_number: manifest.number,
                                                  branch_name: manifest.branch_name)
        create(:freight_expense, :insurance, tenant:, transport_document: document, insurance_rate: rate)
      end
    end

    it 'adds the international insurance and its IOF to the export cargo only' do
      expect { migration.up }.not_to change(FreightExpense, :count)

      expect(FreightExpense.insurance.find_by!(transport_document: national)).to have_attributes(
        international_percentage: nil, international_insurance_cents: 0, iof_cents: 0, amount_cents: 220,
      )
      expect(FreightExpense.insurance.find_by!(transport_document: export)).to have_attributes(
        international_percentage: BigDecimal('0.065'), international_insurance_cents: 650, iof_percentage: BigDecimal('7.38'),
        iof_cents: 48, amount_cents: 918
      )
    end

    it 'can run again without changing the insurance' do
      migration.up

      expect { migration.up }.not_to(change { FreightExpense.order(:id).pluck(:id, :amount_cents, :updated_at) })
    end
  end
end
