require 'rails_helper'

RSpec.describe ProductGroupForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates an active group without products' do
      form = described_class.new(tenant:, name: '  SIDERÚRGICO ', product_names: ['BOBINA'], active: '1')

      expect { expect(form.save).to be(true) }.to change(ProductGroup, :count).by(1)

      product_group = ProductGroup.last
      expect(product_group.tenant).to eq(tenant)
      expect(product_group.name).to eq('SIDERÚRGICO')
      expect(product_group.parent).to be_nil
      expect(product_group.product_names).to eq([])
      expect(product_group.activated_at).to be_present
    end

    context 'with a group' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA') }

      it 'creates an inactive subgroup with its products' do
        form = described_class.new(tenant:, name: 'BOBINA', parent_id: steel.id, product_names: ['', ' BOBINA ', 'BOBINA'], active: '0')

        expect(form.save).to be(true)

        subgroup = ProductGroup.last
        expect(subgroup.parent).to eq(steel)
        expect(subgroup.product_names).to eq(['BOBINA'])
        expect(subgroup.activated_at).to be_nil
      end

      it 'classifies the transport documents of the products of an active subgroup' do
        form = described_class.new(tenant:, name: 'BOBINA', parent_id: steel.id, product_names: ['BOBINA'])

        form.save

        expect(document.reload.product_group).to eq(ProductGroup.last)
      end

      it 'rejects a parent that is not a group of the tenant' do
        form = described_class.new(tenant:, name: 'BOBINA', parent_id: create(:product_group).id)

        expect { expect(form.save).to be_falsey }.not_to change(ProductGroup, :count)
        expect(form.errors[:parent_id]).to eq(['não é um grupo válido'])
      end

      it 'rejects a product already in another subgroup ignoring accents and punctuation' do
        create(:product_subgroup, tenant:, parent: steel, name: 'AÇÚCAR', product_names: ['ACUCAR'])

        form = described_class.new(tenant:, name: 'DOCES', parent_id: steel.id, product_names: ['Açúcar.', 'BOBINA'])

        expect { expect(form.save).to be_falsey }.not_to change(ProductGroup, :count)
        expect(form.errors[:product_names]).to eq(['Açúcar. já estão em outro subgrupo'])
      end
    end

    it 'rejects a group without a name' do
      form = described_class.new(tenant:, name: ' ')

      expect { expect(form.save).to be_falsey }.not_to change(ProductGroup, :count)
      expect(form.errors[:name]).to eq(['não pode ficar em branco'])
    end

    it 'rejects a duplicated name' do
      create(:product_group, tenant:, name: 'SIDERÚRGICO')

      form = described_class.new(tenant:, name: 'SIDERÚRGICO')

      expect(form.save).to be_falsey
      expect(form.errors[:name]).to eq(['já está em uso por outro grupo'])
    end

    context 'when editing a subgroup' do
      let!(:steel) { create(:product_group, tenant:) }
      let!(:subgroup) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: ['BOBINA']) }

      it 'keeps its own products and its group' do
        form = described_class.for_product_group(subgroup)
        form.assign_attributes(name: 'BOBINAS', parent_id: nil, product_names: %w[BOBINA CHAPAS])

        expect(form.save).to be(true)

        expect(subgroup.reload).to have_attributes(name: 'BOBINAS', parent: steel, product_names: %w[BOBINA CHAPAS])
      end
    end
  end

  describe '#available_product_names' do
    let!(:steel) { create(:product_group, tenant:) }
    let!(:subgroup) { create(:product_subgroup, tenant:, parent: steel, product_names: ['BOBINA']) }

    before do
      create_list(:atua_transport_document, 2, tenant:, product_name: 'CHAPAS')
      create(:atua_transport_document, tenant:, product_name: 'BOBINA')
      create(:atua_transport_document, tenant:, product_name: 'ACUCAR')
      create(:atua_transport_document, tenant: create(:tenant), product_name: 'CIMENTO')
    end

    it 'lists the products of the tenant out of the other subgroups with their transport documents count' do
      form = described_class.new(tenant:, parent_id: steel.id)

      expect(form.available_product_names).to eq([['CHAPAS', 2], ['ACUCAR', 1]])
    end

    it 'lists the own products of the subgroup being edited' do
      form = described_class.for_product_group(subgroup)

      expect(form.available_product_names).to eq([['CHAPAS', 2], ['ACUCAR', 1], ['BOBINA', 1]])
    end
  end
end
