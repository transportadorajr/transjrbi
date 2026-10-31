require 'rails_helper'
require Rails.root.join('db/migrate/20261031124925_remove_unused_customer_groups')

RSpec.describe RemoveUnusedCustomerGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  context 'when the tenant has a group without recent takers' do
    let!(:group) { create(:customer_group, tenant:) }

    before do
      create(:atua_customer, tenant:, code: 1, customer_group: group)
      create(:atua_transport_document, tenant:, taker_code: 1, issued_at: 13.months.ago)
    end

    it 'removes the group' do
      expect { migration.up }.to change(CustomerGroup, :count).by(-1)
    end
  end
end
