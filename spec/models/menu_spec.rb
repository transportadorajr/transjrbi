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

  context 'with a resource' do
    let!(:freight_billing) { create(:resource, slug: 'freight_billing') }
    let!(:customers) { create(:resource, slug: 'customers') }
    let(:operator) { create(:user, tenant:, user_type: :operator) }
    let(:ability) { Ability.new(operator) }

    before { create(:access, user: operator, resource: freight_billing, reads: true) }

    it 'is shown when the user can read the resource' do
      expect(described_class.new(name: :freight_billing, resource: 'freight_billing')).to be_show(ability)
    end

    it 'is hidden when the user cannot read the resource' do
      expect(described_class.new(name: :customers, resource: 'customers')).not_to be_show(ability)
    end

    it 'is hidden without an ability' do
      expect(described_class.new(name: :freight_billing, resource: 'freight_billing')).not_to be_show
    end

    it 'hides a group whose items the user cannot read' do
      menu = described_class.new(name: :registrations, menus: [{ name: :customers, resource: 'customers' }])

      expect(menu).not_to be_show(ability)
    end

    it 'shows a group when the user can read one of its items' do
      menu = described_class.new(
        name: :intelligence,
        menus: [{ name: :freight_billing, resource: 'freight_billing' }, { name: :customers, resource: 'customers' }],
      )

      expect(menu).to be_show(ability)
    end

    it 'checks the action against a model' do
      menu = described_class.new(name: :users, resource: 'User', action: 'create')

      expect(menu).not_to be_show(ability)
      expect(menu).to be_show(Ability.new(create(:user, tenant:, user_type: :admin)))
    end
  end
end
