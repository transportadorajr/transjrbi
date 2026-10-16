require 'rails_helper'

RSpec.describe CustomerGroup do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires a name' do
      customer_group = described_class.new(tenant:, name: '')

      expect(customer_group).not_to be_valid
      expect(customer_group.errors[:name]).to be_present
    end

    context 'when the name is already taken in the tenant' do
      let!(:existing_group) { create(:customer_group, tenant:, name: 'TERRAFEC') }

      it 'rejects the duplicated name' do
        expect(described_class.new(tenant:, name: 'TERRAFEC')).not_to be_valid
      end

      it 'accepts the same name in another tenant' do
        expect(described_class.new(tenant: create(:tenant), name: 'TERRAFEC')).to be_valid
      end
    end
  end

  describe '.compact' do
    it 'removes accents, spaces and punctuation and upcases the text' do
      expect(described_class.compact('Terrinha Alimentos - Ltda.')).to eq('TERRINHAALIMENTOSLTDA')
      expect(described_class.compact('Consolata Comércio S/A')).to eq('CONSOLATACOMERCIOSA')
    end

    it 'returns an empty text for nil' do
      expect(described_class.compact(nil)).to eq('')
    end
  end

  describe '#match?' do
    let(:customer_group) { build(:customer_group, terms: ['2JM', 'TERRINHA ALIMENTOS']) }

    it 'matches a name that contains one of the terms ignoring spaces and punctuation' do
      expect(customer_group.match?('TERRINHA-ALIMENTOS LTDA')).to be(true)
      expect(customer_group.match?('2 J.M. COMERCIO')).to be(true)
    end

    it 'matches when any of the given names contains a term' do
      expect(customer_group.match?('DISTRIBUIDORA BH LTDA', 'TERRINHA ALIMENTOS')).to be(true)
    end

    it 'does not match a name without the terms' do
      expect(customer_group.match?('USIMINAS S.A.', nil)).to be(false)
    end

    it 'never matches when the group has no terms' do
      expect(build(:customer_group, terms: []).match?('TERRINHA ALIMENTOS')).to be(false)
    end

    it 'ignores terms without letters or numbers' do
      expect(build(:customer_group, terms: ['---']).match?('USIMINAS S.A.')).to be(false)
    end
  end

  describe '.for_name' do
    let!(:steel) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: %w[TERRAFEC]) }
    let!(:own_group) { create(:customer_group, tenant:, name: 'ARCELOR SEM TERMOS', terms: []) }

    it 'returns the first group whose terms match the name' do
      expect(tenant.customer_groups.for_name('Arcelormittal Brasil S.A.')).to eq(steel)
      expect(tenant.customer_groups.for_name(nil, 'TERRAFEC MG')).to eq(food)
    end

    it 'returns nil when no group matches' do
      expect(tenant.customer_groups.for_name('USIMINAS S.A.')).to be_nil
    end
  end

  describe 'scopes' do
    let!(:active_group) { create(:customer_group, tenant:, name: 'VIRGINIA', terms: ['VIRGINIA']) }
    let!(:inactive_group) { create(:customer_group, tenant:, name: 'MOVISTAR', activated_at: nil) }

    it 'filters by name ignoring the case' do
      expect(described_class.by_name('virg')).to eq([active_group])
    end

    it 'filters by status' do
      expect(described_class.by_status('active')).to eq([active_group])
      expect(described_class.by_status('deactivated')).to eq([inactive_group])
    end

    it 'lists only the groups with terms' do
      expect(described_class.with_terms).to eq([active_group])
    end
  end

  describe '#destroy' do
    let!(:customer_group) { create(:customer_group, tenant:) }

    context 'with customers' do
      let!(:customer) { create(:atua_customer, tenant:, customer_group:) }

      it 'keeps the group and explains why' do
        expect { customer_group.destroy }.not_to change(described_class, :count)

        expect(customer_group.errors.full_messages).to eq(
          ['Não é possível excluir um grupo com clientes ou regras de comissão vinculados. Desative o grupo para deixar de usá-lo.'],
        )
      end
    end

    context 'without customers' do
      it 'removes the group' do
        expect { customer_group.destroy }.to change(described_class, :count).by(-1)
      end
    end
  end
end
