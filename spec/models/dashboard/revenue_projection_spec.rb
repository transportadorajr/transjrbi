require 'rails_helper'

RSpec.describe Dashboard::RevenueProjection do
  describe '.enabled?' do
    let(:tenant) { create(:tenant) }

    it 'is disabled while the flag is off for the tenant' do
      expect(described_class.enabled?(tenant)).to be(false)
    end

    it 'is enabled when the flag is on for the tenant', flipper: { revenue_projection: :tenant } do
      expect(described_class.enabled?(tenant)).to be(true)
    end
  end
end
