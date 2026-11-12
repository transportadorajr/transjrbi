require 'rails_helper'

RSpec.describe OwnFleet do
  let(:tenant) { create(:tenant) }

  describe 'validations' do
    it 'accepts a single fleet per tenant' do
      create(:own_fleet, tenant:)

      expect(build(:own_fleet, tenant:)).not_to be_valid
      expect(build(:own_fleet, tenant: create(:tenant))).to be_valid
    end
  end

  describe '#third_party?' do
    let(:own_fleet) { build(:own_fleet, plates: %w[AJR4391 BCN3I00]) }

    it 'is false for a plate of the fleet, whatever the formatting' do
      expect(own_fleet.third_party?('AJR4391')).to be(false)
      expect(own_fleet.third_party?('bcn-3i00')).to be(false)
    end

    it 'is true for a plate outside the fleet' do
      expect(own_fleet.third_party?('SEH2H90')).to be(true)
    end

    it 'is false for the plate of the international billing' do
      expect(own_fleet.third_party?('INT6R00')).to be(false)
    end

    it 'is false for a blank plate' do
      expect(own_fleet.third_party?(nil)).to be(false)
      expect(own_fleet.third_party?('')).to be(false)
    end

    it 'is false for every plate while the fleet is empty' do
      expect(build(:own_fleet, plates: []).third_party?('SEH2H90')).to be(false)
    end
  end
end
