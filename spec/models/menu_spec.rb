require 'rails_helper'

RSpec.describe Menu do
  let!(:tenant) { create(:tenant) }

  before { Current.tenant = tenant }

  context 'without a feature flag' do
    it 'is shown' do
      expect(described_class.new(name: :freight_billing, url: '/freight_billing')).to be_show
    end
  end

  context 'with a feature flag turned off' do
    it 'is hidden' do
      expect(described_class.new(name: :trips, url: '/trips', feature: 'trips_dashboard')).not_to be_show
    end

    it 'hides a group whose only item is behind the flag' do
      menu = described_class.new(name: :intelligence, menus: [{ name: :trips, url: '/trips', feature: 'trips_dashboard' }])

      expect(menu).not_to be_show
    end
  end

  context 'with a feature flag turned on for the tenant', flipper: { trips_dashboard: :tenant } do
    it 'is shown' do
      expect(described_class.new(name: :trips, url: '/trips', feature: 'trips_dashboard')).to be_show
    end

    it 'is hidden for another tenant' do
      Current.tenant = create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra')

      expect(described_class.new(name: :trips, url: '/trips', feature: 'trips_dashboard')).not_to be_show
    end
  end
end
