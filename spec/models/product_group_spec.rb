require 'rails_helper'

RSpec.describe ProductGroup do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires a name' do
      product_group = described_class.new(tenant:, name: '')

      expect(product_group).not_to be_valid
      expect(product_group.errors[:name]).to be_present
    end

    context 'when the name is already taken' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA') }

      it 'rejects the duplicated name of a group in the tenant' do
        expect(described_class.new(tenant:, name: 'SIDERÚRGICO')).not_to be_valid
      end

      it 'rejects the duplicated name of a subgroup in the same group' do
        expect(described_class.new(tenant:, parent: steel, name: 'BOBINA')).not_to be_valid
      end

      it 'accepts the name of a subgroup in another group' do
        expect(described_class.new(tenant:, parent: create(:product_group, tenant:), name: 'BOBINA')).to be_valid
      end

      it 'accepts the same name in another tenant' do
        expect(described_class.new(tenant: create(:tenant), name: 'SIDERÚRGICO')).to be_valid
      end
    end

    it 'rejects a subgroup inside another subgroup' do
      subgroup = create(:product_subgroup, tenant:)

      product_group = described_class.new(tenant:, parent: subgroup, name: 'BOBINA')

      expect(product_group).not_to be_valid
      expect(product_group.errors[:parent]).to be_present
    end

    it 'rejects a parent of another tenant' do
      product_group = described_class.new(tenant:, parent: create(:product_group), name: 'BOBINA')

      expect(product_group).not_to be_valid
    end
  end

  describe '.classifying' do
    let!(:steel) { create(:product_group, tenant:) }
    let!(:food) { create(:product_group, tenant:, activated_at: nil) }
    let!(:coil) { create(:product_subgroup, tenant:, parent: steel) }
    let!(:rebar) { create(:product_subgroup, tenant:, parent: steel, activated_at: nil) }
    let!(:flour) { create(:product_subgroup, tenant:, parent: food) }

    it 'returns the active subgroups of the active groups' do
      expect(described_class.classifying).to eq([coil])
    end
  end

  describe '#compacted_product_names' do
    it 'removes accents, spaces and punctuation of the product names' do
      product_group = build(:product_subgroup, product_names: ['FERRO (FIO MAQUINA/ VERGALHAO ROLO)', 'Açúcar', '---'])

      expect(product_group.compacted_product_names).to eq(%w[FERROFIOMAQUINAVERGALHAOROLO ACUCAR])
    end
  end

  describe '#destroy' do
    let!(:steel) { create(:product_group, tenant:) }

    it 'keeps a group with subgroups' do
      create(:product_subgroup, tenant:, parent: steel)

      expect(steel.destroy).to be(false)
      expect(steel.errors.full_messages).to eq(['Não é possível excluir um grupo com subgrupos. Exclua os subgrupos ou desative o grupo para deixar de usá-lo.'])
    end

    it 'leaves the transport documents of a removed subgroup without a group' do
      subgroup = create(:product_subgroup, tenant:, parent: steel)
      document = create(:atua_transport_document, tenant:, product_group: subgroup)

      expect { subgroup.destroy }.to change(described_class, :count).by(-1)
      expect(document.reload.product_group).to be_nil
    end
  end
end
