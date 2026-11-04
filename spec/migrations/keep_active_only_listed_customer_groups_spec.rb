require 'rails_helper'
require Rails.root.join('db/migrate/20261104003556_keep_active_only_listed_customer_groups')

RSpec.describe KeepActiveOnlyListedCustomerGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with listed and unlisted customer groups' do
    let!(:tenant) { create(:tenant) }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }
    let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO']) }
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU']) }

    it 'keeps active only the listed customer groups' do
      migration.up

      expect(tenant.customer_groups.activated).to contain_exactly(usiminas, regio)
      expect(gerdau.reload).not_to be_activated
    end
  end
end
