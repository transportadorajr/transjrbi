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
    let!(:moinho) { create(:atua_customer, tenant:, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL') }
    let!(:usiminas) { create(:atua_customer, tenant:, name: 'USINAS SIDERURGICAS DE MINAS GERAIS S\\A - USIMINAS') }
    let!(:usiminas_abbreviated) { create(:atua_customer, tenant:, name: 'USINAS SIDERUR MINAS GERAIS S/A - USIMINAS') }
    let!(:other) { create(:atua_customer, tenant:, name: 'ACME TRANSPORTES S.A.') }

    it 'creates the known groups and links every customer to a group' do
      expect { described_class.call(tenant) }.to change(CustomerGroup, :count).by(23)

      expect(tenant.customer_groups.with_terms.order(:id).pluck(:name, :terms)).to eq(
        [
          ['TERRAFEC', ['2JM', 'TERRAFEC', 'TERRINHA ALIMENTOS']],
          ['VIRGINIA', ['VIRGINIA']],
          ['MOVISTAR', ['MOVISTAR']],
          ['CONSOLATA', ['CONSOLATA']],
          ['ARCELOR', ['ARCELOR']],
          ['RÉGIO', ['MOINHO REGIO']],
          ['USIMINAS', ['USIMINAS']],
          ['RIO AZUL', ['REFARE']],
          ['ALAMEDA', ['ALFLEN']],
          ['TRADIÇÃO', ['ALIMENTOS TRADICAO']],
          ['INDEMIL', ['INDEMIL']],
          ['UNIDAS', ['UNIDAS DISTRIBUIDORA']],
          ['PANORAMA', ['PANORAMA MAT']],
          ['COAGRU', ['COAGRU']],
          ['CASA DO TRIGO', ['CASA DO TRIGO']],
          ['ACB', ['BEBIDAS ACB']],
          ['BIGOLIN', ['BIGOLIN']],
          ['ARAUCO', ['ARAUCO']],
          ['GERDAU', ['GERDAU']],
          ['RUDOLF', ['RUDOLF SIZING']],
          ['MULTIAMIDOS', ['MULTIAMIDOS']],
          ['SOORO', ['SOORO']],
        ],
      )
      expect(tenant.customer_groups.not_activated.count).to eq(0)
      expect(jm.reload.customer_group.name).to eq('TERRAFEC')
      expect(terrinha.reload.customer_group.name).to eq('TERRAFEC')
      expect(steel.reload.customer_group.name).to eq('ARCELOR')
      expect(virginia.reload.customer_group.name).to eq('VIRGINIA')
      expect(movistar.reload.customer_group.name).to eq('MOVISTAR')
      expect(consolata.reload.customer_group.name).to eq('CONSOLATA')
      expect(moinho.reload.customer_group.name).to eq('RÉGIO')
      expect(usiminas.reload.customer_group.name).to eq('USIMINAS')
      expect(usiminas_abbreviated.reload.customer_group.name).to eq('USIMINAS')
      expect(other.reload.customer_group.name).to eq('ACME TRANSPORTES S.A.')
      expect(tenant.atua_customers.without_customer_group.count).to eq(0)
    end

    it 'can run again without duplicating or moving anything' do
      described_class.call(tenant)

      expect { described_class.call(tenant) }.not_to change(CustomerGroup, :count)
      expect(steel.reload.customer_group.name).to eq('ARCELOR')
    end
  end

  context 'when an import already gave the customers their own groups' do
    let!(:steel) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.') }

    before { CustomerGroups::AssignCommand.call(tenant) }

    it 'moves them to the known group and removes the empty own group' do
      expect(steel.reload.customer_group.name).to eq('ARCELORMITTAL BRASIL S.A.')

      described_class.call(tenant)

      expect(steel.reload.customer_group.name).to eq('ARCELOR')
      expect(tenant.customer_groups.exists?(name: 'ARCELORMITTAL BRASIL S.A.')).to be(false)
    end
  end

  context 'when the groups were created with their former names' do
    let!(:steel_group) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
    let!(:mill_group) { create(:customer_group, tenant:, name: 'MOINHO REGIO', terms: ['MOINHO REGIO']) }
    let!(:steel) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL BRASIL S.A.', customer_group: steel_group) }

    it 'renames them in place keeping their customers' do
      described_class.call(tenant)

      expect(steel_group.reload.name).to eq('ARCELOR')
      expect(mill_group.reload.name).to eq('RÉGIO')
      expect(steel.reload.customer_group).to eq(steel_group)
      expect(tenant.customer_groups.exists?(name: ['ARCELORMITTAL', 'MOINHO REGIO'])).to be(false)
    end
  end

  context 'when the renamed group already exists next to the former one' do
    let!(:former) { create(:customer_group, tenant:, name: 'ARCELORMITTAL', terms: ['ARCELOR']) }
    let!(:current) { create(:customer_group, tenant:, name: 'ARCELOR', terms: ['ARCELOR']) }

    it 'leaves both untouched' do
      described_class.call(tenant)

      expect(former.reload.name).to eq('ARCELORMITTAL')
      expect(current.reload.name).to eq('ARCELOR')
    end
  end

  context 'with customers split across the branches of the same companies' do
    let!(:customers) do
      {
        'RIO AZUL' => 'REFARE LTDA',
        'ALAMEDA' => 'ALFLEN E ALFLEN LTDA',
        'TRADIÇÃO' => 'INDUSTRIA DE ALIMENTOS TRADICAO LTDA',
        'INDEMIL' => 'INDEMIL INDUSTRIA E COMERCIO S/A',
        'UNIDAS' => 'UNIDAS DISTRIBUIDORA DE BEBIDAS LTDA',
        'PANORAMA' => 'PANORAMA MATERIAIS DE CONSTRUCAO LTDA',
        'COAGRU' => 'COAGRU COOPERATIVA AGROINDUSTRIAL UNIAO',
        'CASA DO TRIGO' => 'CASA DO TRIGO COMERCIO E DISTRIBUICAO LTDA',
        'ACB' => 'DISTRIBUIDORA DE BEBIDAS ACB LTDA CHAPECO',
        'BIGOLIN' => 'BIGOLIN MAT DE CONSTR LTDA',
        'ARAUCO' => 'ARAUCO IND PAINEIS-MONTENEGRO',
        'GERDAU' => 'GERDAU S.A.',
        'RUDOLF' => 'RUDOLF SIZING AMIDOS DO BRASIL LTDA',
        'MULTIAMIDOS' => 'MULTIAMIDOS - INDUSTRIA E COMERCIO LTDA',
        'SOORO' => 'SOORO RENNER NUTRICAO S/A',
      }.transform_values { |name| create(:atua_customer, tenant:, name:) }
    end

    before { CustomerGroups::AssignCommand.call(tenant) }

    it 'moves each one to the group with the short name' do
      described_class.call(tenant)

      expect(customers.transform_values { |customer| customer.reload.customer_group.name }).to eq(customers.to_h { |name, _| [name, name] })
    end
  end

  context 'with customers whose names only resemble the known terms' do
    let!(:beverages) { create(:atua_customer, tenant:, name: 'CERV.REUNIDAS SKOL CARACU') }
    let!(:vac) { create(:atua_customer, tenant:, name: 'SOCIEDADE EM CONTA DE PARTICIPACAO VAC BRASIL EMBALAGENS SCP') }
    let!(:regional) { create(:atua_customer, tenant:, name: 'REGIONAL INDUSTRIA E COMERCIO DE PRODUTOS SIDERURGICOS LTDA') }
    let!(:traditional) { create(:atua_customer, tenant:, name: 'SALGADINHOS TRADICIONAL IND LTDA') }

    it 'keeps them in their own groups' do
      described_class.call(tenant)

      expect([beverages, vac, regional, traditional].map { |customer| customer.reload.customer_group.name })
        .to eq([beverages, vac, regional, traditional].map(&:name))
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
