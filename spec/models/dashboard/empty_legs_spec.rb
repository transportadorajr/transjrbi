require 'rails_helper'

RSpec.describe Dashboard::EmptyLegs do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }
  let!(:vale_do_aco) { create(:macro_region, tenant:) }
  let!(:oeste_parana) { create(:macro_region, tenant:, name: 'OESTE PARANA', state: 'PR', city_names: ['Cascavel']) }

  context 'when there are empty legs' do
    before do
      create(:atua_transport_document, tenant:, code: 90_001, origin_macro_region: vale_do_aco)
      create(:atua_transport_document, tenant:, code: 90_002, origin_macro_region: oeste_parana)
      create(:atua_transport_document, tenant:, code: 90_003, origin_macro_region: oeste_parana)
      first = create(:empty_leg, tenant:, next_manifest_code: 41_200, distance_km: BigDecimal('100'))
      second = create(:empty_leg, tenant:, next_manifest_code: 41_300, distance_km: BigDecimal('250.5'))
      third = create(:empty_leg, tenant:, next_manifest_code: 41_400, distance_km: BigDecimal('300'))
      create(:empty_leg, tenant:, next_manifest_code: 41_500, distance_km: BigDecimal('40'))
      create(:empty_leg, tenant:, next_manifest_code: 41_600, status_type: 'unlocated', distance_km: nil, precision_type: nil)
      create(:empty_leg, tenant: other_tenant, next_manifest_code: 41_700, distance_km: BigDecimal('999'))
      create(:empty_leg_transport_document, empty_leg: first, transport_document_code: 90_001)
      create(:empty_leg_transport_document, empty_leg: second, transport_document_code: 90_002)
      create(:empty_leg_transport_document, empty_leg: third, transport_document_code: 90_003)
    end

    let(:dashboard) { described_class.new(tenant.empty_legs.order(:id)) }

    it 'sums the calculated legs only' do
      expect(dashboard.legs_count).to eq(4)
      expect(dashboard.total_km).to eq(BigDecimal('690.5'))
      expect(dashboard.average_km).to eq(BigDecimal('172.63'))
      expect(dashboard.unmeasured_count).to eq(1)
    end

    it 'ranks the loading macro regions by the empty km' do
      expect(dashboard.regions.map(&:to_h)).to eq(
        [
          { name: 'OESTE PARANA', legs_count: 2, total_km: BigDecimal('550.5') },
          { name: 'VALE DO AÇO/MG', legs_count: 1, total_km: BigDecimal('100') },
          { name: 'Outras', legs_count: 1, total_km: BigDecimal('40') },
        ],
      )
      expect(dashboard.regions.first.average_km).to eq(BigDecimal('275.25'))
    end
  end

  context 'when there are no empty legs' do
    let(:dashboard) { described_class.new(tenant.empty_legs) }

    it 'returns zero totals and no regions' do
      expect(dashboard.legs_count).to eq(0)
      expect(dashboard.total_km).to eq(0)
      expect(dashboard.average_km).to be_nil
      expect(dashboard.regions).to eq([])
    end
  end
end
