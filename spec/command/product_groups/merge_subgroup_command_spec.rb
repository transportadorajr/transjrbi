require 'rails_helper'

RSpec.describe ProductGroups::MergeSubgroupCommand do
  let(:tenant) { create(:tenant) }
  let!(:group) { create(:product_group, tenant:, name: 'BEBIDAS') }

  context 'when the group has both subgroups' do
    let!(:beverages) { create(:product_subgroup, tenant:, parent: group, name: 'BEBIDAS', product_names: %w[CERVEJA]) }
    let!(:bottles) { create(:product_subgroup, tenant:, parent: group, name: 'VASILHAMES', product_names: %w[VASILHAME]) }
    let!(:beer_document) { create(:atua_transport_document, tenant:, product_name: 'CERVEJA') }
    let!(:bottle_document) { create(:atua_transport_document, tenant:, product_name: 'VASILHAME') }

    before { ProductGroups::AssignCommand.call(tenant) }

    it 'moves the products and documents of the source into the target and removes the source' do
      expect { expect(described_class.call(tenant, 'VASILHAMES', 'BEBIDAS')).to eq(beverages) }.to change(ProductGroup, :count).by(-1)

      expect(group.subgroups.pluck(:name, :product_names)).to eq([['BEBIDAS', %w[CERVEJA VASILHAME]]])
      expect([beer_document, bottle_document].map { |document| document.reload.product_group }).to eq([beverages] * 2)
    end

    it 'can run again without changing the subgroups' do
      described_class.call(tenant, 'VASILHAMES', 'BEBIDAS')

      expect { described_class.call(tenant, 'VASILHAMES', 'BEBIDAS') }.not_to(change { ProductGroup.order(:id).pluck(:id, :name, :product_names) })
    end
  end

  context 'when the group has only the source subgroup' do
    let!(:bottles) { create(:product_subgroup, tenant:, parent: group, name: 'VASILHAMES', product_names: %w[VASILHAME]) }
    let!(:bottle_document) { create(:atua_transport_document, tenant:, product_name: 'VASILHAME') }

    it 'renames the source to the target' do
      expect { described_class.call(tenant, 'VASILHAMES', 'BEBIDAS') }.not_to change(ProductGroup, :count)

      expect(bottles.reload).to have_attributes(name: 'BEBIDAS', product_names: %w[VASILHAME])
      expect(bottle_document.reload.product_group).to eq(bottles)
    end
  end
end
