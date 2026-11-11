require 'rails_helper'
require Rails.root.join('db/migrate/20261111135021_mark_toll_reimbursed_customer_groups')

RSpec.describe MarkTollReimbursedCustomerGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with the groups whose toll is charged back by a complement' do
    let!(:tenant) { create(:tenant) }
    let!(:indemil) { create(:customer_group, tenant:, name: 'INDEMIL') }
    let!(:sooro) { create(:customer_group, tenant:, name: 'SOORO') }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }

    it 'stops discounting the toll of Indemil and Sooro only' do
      migration.up

      expect(CustomerGroup.count).to eq(3)
      expect([indemil, sooro, usiminas].map { |group| group.reload.toll_reimbursed }).to eq([true, true, false])
    end
  end
end
