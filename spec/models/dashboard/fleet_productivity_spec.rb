require 'rails_helper'

RSpec.describe Dashboard::FleetProductivity do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:vale_do_aco) { create(:macro_region, tenant:) }
  let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: ['Cascavel']) }
  let(:macro_regions) { tenant.macro_regions.activated.preload(:cities) }

  context 'when there are empty legs' do
    let!(:ipatinga) { create(:location, lookup_key: '|IPATINGA|MG', city: 'IPATINGA', state: 'MG') }
    let!(:cascavel) { create(:location, lookup_key: '|CASCAVEL|PR', city: 'CASCAVEL', state: 'PR') }
    let!(:betim) { create(:location, lookup_key: '|BETIM|MG', city: 'BETIM', state: 'MG') }
    let!(:contagem) { create(:location, lookup_key: '|CONTAGEM|MG', city: 'Contagem', state: 'MG') }
    let(:dashboard) { described_class.new(tenant.empty_legs.where(next_manifest_code: [41_100, 41_200, 41_300, 41_400, 41_500, 41_600]), macro_regions:) }

    before do
      create(:empty_leg, tenant:, next_manifest_code: 41_100, origin: ipatinga, destination: betim, distance_km: BigDecimal('217.44'))
      create(:empty_leg, tenant:, next_manifest_code: 41_200, origin: ipatinga, destination: betim, distance_km: BigDecimal('220'))
      create(:empty_leg, tenant:, next_manifest_code: 41_300, origin: cascavel, destination: contagem, distance_km: BigDecimal('1300'))
      create(:empty_leg, tenant:, next_manifest_code: 41_400, origin: betim, destination: contagem, distance_km: BigDecimal('25'))
      create(:empty_leg, tenant:, next_manifest_code: 41_500, status_type: 'unlocated', distance_km: nil, precision_type: nil)
      create(:empty_leg, tenant:, next_manifest_code: 41_600, status_type: 'unrouted', origin: ipatinga, destination: betim, distance_km: nil)
      create(:empty_leg, tenant:, next_manifest_code: 41_700, origin: ipatinga, destination: betim, distance_km: BigDecimal('500'))
      create(:empty_leg, tenant: other_tenant, next_manifest_code: 41_100, origin: ipatinga, destination: betim, distance_km: BigDecimal('999'))
    end

    it 'ranks the routes from the unloading to the loading city by the empty km' do
      expect(dashboard.routes.map(&:to_h)).to eq(
        [
          { key: 'CASCAVEL|PR|CONTAGEM|MG', label: 'CASCAVEL/PR → CONTAGEM/MG', legs_count: 1, total_km: BigDecimal('1300') },
          { key: 'IPATINGA|MG|BETIM|MG', label: 'IPATINGA/MG → BETIM/MG', legs_count: 2, total_km: BigDecimal('437.44') },
          { key: 'BETIM|MG|CONTAGEM|MG', label: 'BETIM/MG → CONTAGEM/MG', legs_count: 1, total_km: BigDecimal('25') },
        ],
      )
      expect(dashboard.routes.second.average_km).to eq(BigDecimal('218.72'))
    end

    it 'ranks the macro regions of the unloading city by the empty km' do
      expect(dashboard.unloading_regions.map { |region| region.to_h.except(:key) }).to eq(
        [
          { label: 'OESTE PARANA', legs_count: 1, total_km: BigDecimal('1300') },
          { label: 'VALE DO AÇO/MG', legs_count: 2, total_km: BigDecimal('437.44') },
          { label: 'Sem macro região', legs_count: 1, total_km: BigDecimal('25') },
        ],
      )
    end

    it 'sums the measured legs and counts the legs that could not be measured apart' do
      expect(dashboard.legs_count).to eq(4)
      expect(dashboard.total_km).to eq(BigDecimal('1762.44'))
      expect(dashboard.average_km).to eq(BigDecimal('440.61'))
      expect(dashboard.unmeasured_count).to eq(2)
      expect(dashboard).not_to be_empty
    end

    it 'plots the empty km of the routes' do
      expect(dashboard.routes_chart_data).to eq(
        [{ name: 'KM vazio', data: { 'CASCAVEL/PR → CONTAGEM/MG' => 1300.0, 'IPATINGA/MG → BETIM/MG' => 437.44, 'BETIM/MG → CONTAGEM/MG' => 25.0 } }],
      )
    end
  end

  context 'when there are no measured empty legs' do
    before { create(:empty_leg, tenant:, status_type: 'unlocated', distance_km: nil, precision_type: nil) }

    let(:dashboard) { described_class.new(tenant.empty_legs, macro_regions:) }

    it 'returns no rankings' do
      expect(dashboard).to be_empty
      expect(dashboard.legs_count).to eq(0)
      expect(dashboard.average_km).to be_nil
      expect(dashboard.routes).to eq([])
      expect(dashboard.unloading_regions).to eq([])
      expect(dashboard.unmeasured_count).to eq(1)
    end
  end
end
