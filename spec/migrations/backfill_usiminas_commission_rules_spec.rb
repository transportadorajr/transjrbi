require 'rails_helper'
require Rails.root.join('db/migrate/20261015191722_backfill_usiminas_commission_rules')

RSpec.describe BackfillUsiminasCommissionRules do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }

    it 'registers the Usiminas commission rules of every tenant' do
      expect { migration.up }.to change(CommissionRule, :count).by(6)

      expect(tenant.commission_rules.pluck(:name)).to contain_exactly('Nacional', 'Argentina', 'Paraguai')
      expect(other_tenant.commission_rules.pluck(:name)).to contain_exactly('Nacional', 'Argentina', 'Paraguai')
    end

    it 'can run again without duplicating the rules' do
      migration.up

      expect { migration.up }.not_to change(CommissionRule, :count)
    end
  end
end
