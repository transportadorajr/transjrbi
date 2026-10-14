require 'rails_helper'

RSpec.describe CustomerGroups::BackfillCommand do
  let(:tenant) { create(:tenant) }

  context 'with customers of the known companies' do
    let!(:jm) { create(:atua_customer, tenant:, name: '2JM COMERCIO LTDA') }
    let!(:terrinha) { create(:atua_customer, tenant:, name: 'TERRINHA ALIMENTOS LTDA') }
    let!(:steel) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }
    let!(:virginia) { create(:atua_customer, tenant:, name: 'TRANSPORTES VIRGINIA LTDA') }
    let!(:movistar) { create(:atua_customer, tenant:, name: 'MOVISTAR LOGISTICA') }
    let!(:consolata) { create(:atua_customer, tenant:, name: 'Consolata Comércio S/A') }
    let!(:other) { create(:atua_customer, tenant:, name: 'USIMINAS S.A.') }

    it 'creates the known groups and links every customer to a group' do
      expect { described_class.call(tenant) }.to change(CustomerGroup, :count).by(6)

      expect(tenant.customer_groups.with_terms.order(:id).pluck(:name, :terms)).to eq(
        [
          ['TERRAFEC', ['2JM', 'TERRAFEC', 'TERRINHA ALIMENTOS']],
          ['VIRGINIA', ['VIRGINIA']],
          ['MOVISTAR', ['MOVISTAR']],
          ['CONSOLATA', ['CONSOLATA']],
          ['ARCELORMITTAL', ['ARCELOR']],
        ],
      )
      expect(tenant.customer_groups.not_activated.count).to eq(0)
      expect(jm.reload.customer_group.name).to eq('TERRAFEC')
      expect(terrinha.reload.customer_group.name).to eq('TERRAFEC')
      expect(steel.reload.customer_group.name).to eq('ARCELORMITTAL')
      expect(virginia.reload.customer_group.name).to eq('VIRGINIA')
      expect(movistar.reload.customer_group.name).to eq('MOVISTAR')
      expect(consolata.reload.customer_group.name).to eq('CONSOLATA')
      expect(other.reload.customer_group.name).to eq('USIMINAS S.A.')
      expect(tenant.atua_customers.without_customer_group.count).to eq(0)
    end

    it 'can run again without duplicating or moving anything' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change(CustomerGroup, :count)
      expect(steel.reload.customer_group.name).to eq('ARCELORMITTAL')
    end
  end

  context 'when an import already gave the customers their own groups' do
    let!(:steel) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }

    before { CustomerGroups::AssignCommand.call(tenant) }

    it 'moves them to the known group and removes the empty own group' do
      expect(steel.reload.customer_group.name).to eq('ARCELORMITTAL BRASIL S.A.')

      described_class.call(tenant)

      expect(steel.reload.customer_group.name).to eq('ARCELORMITTAL')
      expect(tenant.customer_groups.exists?(name: 'ARCELORMITTAL BRASIL S.A.')).to be(false)
    end
  end

  context 'when a known group was edited by the user' do
    let!(:food) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: ['TERRAFEC'], activated_at: nil) }

    it 'keeps the terms and the status chosen by the user' do
      described_class.call(tenant)

      food.reload
      expect(food.terms).to eq(['TERRAFEC'])
      expect(food.activated_at).to be_nil
    end
  end
end
