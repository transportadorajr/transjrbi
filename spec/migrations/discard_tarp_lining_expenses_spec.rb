require 'rails_helper'
require Rails.root.join('db/migrate/20261106133727_discard_tarp_lining_expenses')

RSpec.describe DiscardTarpLiningExpenses do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with a R$ 55,00 tarp lining paid to Régio and another expense' do
    let!(:tenant) { create(:tenant) }
    let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO']) }
    let!(:cascavel) { create(:atua_customer, tenant:, code: 3783, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', customer_group: regio) }
    let!(:lining) { create(:atua_expense, tenant:, payee_code: 3783, total_cents: 5_500) }
    let!(:fuel) { create(:atua_expense, tenant:, total_cents: 5_500) }

    it 'discards only the tarp lining' do
      migration.up

      expect(Atua::Expense.active).to eq([fuel])
      expect(lining.reload.removed_from_atua_at).to be_present
    end
  end
end
