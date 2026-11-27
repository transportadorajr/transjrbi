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

  it 'translates the status and the precision' do
    leg = build(:empty_leg, status_type: 'unrouted', precision_type: 'city')

    expect(leg.status_type_name).to eq('Rota não encontrada')
    expect(leg.precision_type_name).to eq('Centro da cidade')
  end
end
