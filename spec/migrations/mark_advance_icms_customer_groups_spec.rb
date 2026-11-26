require 'rails_helper'
require Rails.root.join('db/migrate/20261126181722_mark_advance_icms_customer_groups')

RSpec.describe MarkAdvanceIcmsCustomerGroups do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with the groups whose advance ICMS guides are paid by the carrier' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU') }
    let!(:other_gerdau) { create(:customer_group, tenant: other_tenant, name: 'GERDAU') }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:marked_at) { Time.zone.local(2026, 11, 1, 8) }
    let!(:marked) { create(:customer_group, tenant:, name: 'RUDOLF', pays_advance_icms_at: marked_at) }

    it 'marks the Gerdau groups of every tenant only' do
      migration.up

      expect(CustomerGroup.count).to eq(4)
      expect([gerdau, other_gerdau, usiminas].map { |group| group.reload.pays_advance_icms? }).to eq([true, true, false])
      expect(marked.reload.pays_advance_icms_at).to eq(marked_at)
    end

    it 'keeps the date of a group already marked when it runs again' do
      migration.up
      first_marked_at = gerdau.reload.pays_advance_icms_at

      travel 1.day do
        migration.up
      end

      expect(gerdau.reload.pays_advance_icms_at).to eq(first_marked_at)
    end
  end
end
