require 'rails_helper'
require Rails.root.join('db/migrate/20261126173946_unify_gerdau_customer_group')

RSpec.describe UnifyGerdauCustomerGroup do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }
  let!(:tenant_without_gerdau) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  context 'when the GERDAU group is inactive and some GERDAU customers are elsewhere' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU'], activated_at: nil) }
    let!(:steel) { create(:customer_group, tenant:, name: 'ACOMINAS', terms: ['ACOMINAS']) }
    let!(:customer) { create(:atua_customer, tenant:, name: 'GERDAU ACOMINAS S.A.', customer_group: steel) }
    let!(:ungrouped) { create(:atua_customer, tenant:, name: 'GERDAU ACOS LONGOS S.A.') }
    let!(:other_customer) { create(:atua_customer, tenant: tenant_without_gerdau, name: 'TERRAFEC LTDA') }

    it 'moves every GERDAU customer into the group and activates it' do
      expect { migration.up }.not_to change(CustomerGroup, :count)

      expect(gerdau.reload).to be_activated
      expect(gerdau.customers).to contain_exactly(customer, ungrouped)
      expect(tenant_without_gerdau.customer_groups).to be_empty
    end

    it 'can run again without changing anything' do
      migration.up

      expect { migration.up }.not_to(change { [CustomerGroup.count, gerdau.reload.updated_at] })
    end
  end
end
