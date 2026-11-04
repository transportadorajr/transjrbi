require 'rails_helper'
require Rails.root.join('db/migrate/20261104001454_keep_active_only_product_groups_with_recent_documents')

RSpec.describe KeepActiveOnlyProductGroupsWithRecentDocuments do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  around { |example| travel_to(Time.zone.local(2026, 11, 3, 12)) { example.run } }

  context 'with subgroups used only more than three months ago' do
    let!(:tenant) { create(:tenant) }
    let!(:group) { create(:product_group, tenant:, name: 'CELULOSE E PAPEL') }
    let!(:pulp) { create(:product_subgroup, tenant:, parent: group, name: 'CELULOSE', product_names: %w[CELULOSE]) }
    let!(:paper) { create(:product_subgroup, tenant:, parent: group, name: 'PAPEL', product_names: %w[PAPEL]) }

    before do
      create(:atua_transport_document, tenant:, product_name: 'CELULOSE', issued_at: Time.zone.local(2026, 8, 10))
      create(:atua_transport_document, tenant:, product_name: 'PAPEL', issued_at: Time.zone.local(2026, 7, 31))
      ProductGroups::AssignCommand.call(tenant)
    end

    it 'keeps active only the product groups with documents issued in the last three months' do
      migration.up

      expect(tenant.product_groups.activated).to contain_exactly(group, pulp)
      expect(paper.reload).not_to be_activated
    end
  end
end
