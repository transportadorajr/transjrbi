require 'rails_helper'

RSpec.describe EmptyLeg do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'validations' do
    it 'requires the distance of a calculated leg' do
      leg = build(:empty_leg, tenant:, status_type: 'calculated', distance_km: nil)

      expect(leg).not_to be_valid
      expect(leg.errors[:distance_km]).to be_present
    end

    it 'accepts a leg without distance when the address was not located' do
      expect(build(:empty_leg, tenant:, status_type: 'unlocated', distance_km: nil, precision_type: nil)).to be_valid
    end

    it 'keeps a single leg per next manifest of the tenant' do
      create(:empty_leg, tenant:, next_manifest_code: 41_300)

      expect(build(:empty_leg, tenant:, next_manifest_code: 41_300)).not_to be_valid
      expect(build(:empty_leg, tenant: other_tenant, next_manifest_code: 41_300)).to be_valid
    end

    it 'rejects an unknown status' do
      expect(build(:empty_leg, tenant:, status_type: 'pending')).not_to be_valid
    end
  end

  describe 'associations' do
    let!(:previous_manifest) { create(:atua_manifest, tenant:, code: 41_100) }
    let!(:next_manifest) { create(:atua_manifest, tenant:, code: 41_200) }
    let!(:leg) { create(:empty_leg, tenant:, previous_manifest_code: 41_100, next_manifest_code: 41_200) }

    before do
      create(:atua_manifest, tenant: other_tenant, code: 41_100)
      create(:atua_manifest, tenant: other_tenant, code: 41_200)
    end

    it 'reaches both manifests inside the tenant' do
      expect(leg.previous_manifest).to eq(previous_manifest)
      expect(leg.next_manifest).to eq(next_manifest)
      expect(next_manifest.empty_leg).to eq(leg)
    end
  end

  describe 'listing filters' do
    let!(:vale_do_aco) { create(:macro_region, tenant:) }
    let!(:coamo) { create(:customer_group, tenant:, name: 'COAMO') }
    let!(:near) { create(:empty_leg, tenant:, plate: 'EXU0F72', next_manifest_code: 41_200, distance_km: BigDecimal('48.2')) }
    let!(:far) { create(:empty_leg, tenant:, plate: 'QWE1A23', next_manifest_code: 41_300, distance_km: BigDecimal('612.5')) }
    let!(:unregioned) { create(:empty_leg, tenant:, plate: 'QWE1A23', next_manifest_code: 41_400, distance_km: BigDecimal('150')) }

    before do
      create(:atua_manifest, tenant:, code: 41_200, plate: 'EXU0F72', trip_started_at: Time.zone.local(2026, 9, 30, 22))
      create(:atua_manifest, tenant:, code: 41_300, plate: 'QWE1A23', trip_started_at: nil, departure_on: Date.new(2026, 10, 15))
      create(:atua_manifest, tenant:, code: 41_400, plate: 'QWE1A23', trip_started_at: Time.zone.local(2026, 11, 2, 8))
      create(:atua_customer, tenant:, code: 7501, customer_group: coamo)
      create(:atua_transport_document, tenant:, code: 90_001, taker_code: 7501, origin_macro_region: vale_do_aco)
      create(:atua_transport_document, tenant:, code: 90_002, origin_macro_region: nil)
      create(:atua_transport_document, tenant:, code: 90_003, origin_macro_region: nil)
      create(:empty_leg_transport_document, empty_leg: far, transport_document_code: 90_001)
      create(:empty_leg_transport_document, empty_leg: far, transport_document_code: 90_002)
      create(:empty_leg_transport_document, empty_leg: unregioned, transport_document_code: 90_003)
    end

    it 'filters by the trip date of the next manifest' do
      expect(described_class.by_trip_start('2026-10-01')).to contain_exactly(far, unregioned)
      expect(described_class.by_trip_end('2026-10-31')).to contain_exactly(near, far)
      expect(described_class.by_trip_start('2026-10-01').by_trip_end('2026-10-31')).to contain_exactly(far)
    end

    it 'filters by the plate typed in any format' do
      expect(described_class.by_plate('exu-0f72')).to contain_exactly(near)
    end

    it 'keeps only the legs that ran at least the minimum distance' do
      expect(described_class.by_min_distance('150')).to contain_exactly(far, unregioned)
    end

    it 'filters by the macro region of the first loaded transport document' do
      expect(described_class.by_loading_macro_region(vale_do_aco.id.to_s)).to contain_exactly(far)
      expect(described_class.by_loading_macro_region(MacroRegion::OTHERS)).to contain_exactly(near, unregioned)
    end

    it 'filters by the customer group of the loaded transport documents' do
      expect(described_class.by_customer_group(coamo.id)).to contain_exactly(far)
    end

    it 'reads the name of the loading macro region' do
      legs = described_class.with_loading_macro_region.index_by(&:id)

      expect(legs[far.id][:loading_macro_region_name]).to eq('VALE DO AÇO/MG')
      expect(legs[unregioned.id][:loading_macro_region_name]).to be_nil
    end
  end

  it 'translates every exported header' do
    columns = described_class.export_columns.reject { |column| described_class::EXPORT_EXCEPTIONS.include?(column.name) }

    expect(columns).to all(be_translated)
  end

  it 'translates the status and the precision' do
    leg = build(:empty_leg, status_type: 'unrouted', precision_type: 'city')

    expect(leg.status_type_name).to eq('Rota não encontrada')
    expect(leg.precision_type_name).to eq('Centro da cidade')
  end
end
