require 'rails_helper'
require Rails.root.join('db/migrate/20261127182333_mark_export_summary_customer_groups')

RSpec.describe MarkExportSummaryCustomerGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with the groups whose exports enter the export summary' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }
    let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELOR') }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:other_usiminas) { create(:customer_group, tenant: other_tenant, name: 'USIMINAS') }
    let!(:indemil) { create(:customer_group, tenant:, name: 'INDEMIL') }
    let!(:marked_at) { Time.zone.local(2026, 11, 1, 8) }
    let!(:marked) { create(:customer_group, tenant:, name: 'GERDAU', in_export_summary_at: marked_at) }

    it 'marks the Arcelor and Usiminas groups of every tenant only' do
      migration.up

      expect(CustomerGroup.count).to eq(5)
      expect([arcelor, usiminas, other_usiminas, indemil].map { |group| group.reload.in_export_summary? }).to eq([true, true, true, false])
      expect(marked.reload.in_export_summary_at).to eq(marked_at)
    end

    it 'keeps the date of a group already marked when it runs again' do
      migration.up
      first_marked_at = arcelor.reload.in_export_summary_at

      travel 1.day do
        migration.up
      end

      expect(arcelor.reload.in_export_summary_at).to eq(first_marked_at)
    end
  end
end
