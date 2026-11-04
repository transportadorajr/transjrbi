require 'rails_helper'

RSpec.describe ProductGroups::ActivateByDocumentsCommand do
  let(:tenant) { create(:tenant) }
  let(:period) { Date.new(2026).all_year }

  context 'with subgroups that had documents in the period and others that did not' do
    let!(:food) { create(:product_group, tenant:, name: 'ALIMENTÍCIO') }
    let!(:paper) { create(:product_group, tenant:, name: 'CELULOSE E PAPEL', activated_at: nil) }
    let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
    let!(:flour) { create(:product_subgroup, tenant:, parent: food, name: 'FARINHAS', product_names: %w[FARINHA]) }
    let!(:oils) { create(:product_subgroup, tenant:, parent: food, name: 'ÓLEOS', product_names: %w[MARGARINA]) }
    let!(:pulp) { create(:product_subgroup, tenant:, parent: paper, name: 'CELULOSE', product_names: %w[CELULOSE], activated_at: nil) }
    let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: %w[BOBINA]) }
    let!(:other_tenant_group) { create(:product_group, name: 'OUTRO') }
    let!(:flour_document) { create(:atua_transport_document, tenant:, product_name: 'FARINHA', issued_at: Time.zone.local(2026, 3, 10)) }
    let!(:old_oil_document) { create(:atua_transport_document, tenant:, product_name: 'MARGARINA', issued_at: Time.zone.local(2025, 12, 31)) }
    let!(:pulp_document) { create(:atua_transport_document, tenant:, product_name: 'CELULOSE', issued_at: Time.zone.local(2026, 1, 5)) }

    before do
      create(:atua_transport_document, tenant:, product_name: 'BOBINA', issued_at: Time.zone.local(2026, 2, 1), canceled_at: Time.zone.local(2026, 2, 2))
      ProductGroups::AssignCommand.call(tenant)
    end

    it 'keeps active only the groups and subgroups with documents issued in the period' do
      expect(described_class.call(tenant, period)).to contain_exactly(food, flour, paper, pulp)

      expect(tenant.product_groups.not_activated).to contain_exactly(oils, steel, coil)
      expect(other_tenant_group.reload).to be_activated
    end

    it 'classifies the documents only in the active subgroups' do
      described_class.call(tenant, period)

      expect([flour_document, old_oil_document, pulp_document].map { |document| document.reload.product_group }).to eq([flour, nil, pulp])
    end

    it 'can run again without changing the product groups' do
      described_class.call(tenant, period)

      expect { described_class.call(tenant, period) }.not_to(change { ProductGroup.order(:id).pluck(:id, :activated_at) })
    end
  end
end
