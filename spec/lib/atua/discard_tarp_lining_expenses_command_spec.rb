require 'rails_helper'

RSpec.describe Atua::DiscardTarpLiningExpensesCommand do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  context 'with expenses paid to the Régio units of Cascavel and Cuiabá' do
    let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO']) }
    let!(:cascavel) { create(:atua_customer, tenant:, code: 3783, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', customer_group: regio) }
    let!(:cuiaba) { create(:atua_customer, tenant:, code: 7684, name: 'MOINHO REGIO ALIMENTOS S/A - CUIABA', customer_group: regio) }
    let!(:document) { create(:atua_transport_document, tenant:) }
    let!(:cascavel_lining) do
      create(:atua_expense, tenant:, payee_code: 3783, history_code: 72, total_cents: 5_500, description: 'LONAS PAGA A MOINHO REGIO',
                            cost_object: document)
    end
    let!(:cuiaba_lining) { create(:atua_expense, tenant:, payee_code: 7684, history_code: 502, total_cents: 5_500) }
    let!(:regio_unloading) { create(:atua_expense, tenant:, payee_code: 3783, history_code: 72, total_cents: 7_000) }
    let!(:other_payee) { create(:atua_expense, tenant:, payee_code: 9999, history_code: 72, total_cents: 5_500) }
    let!(:other_tenant_lining) do
      other_group = create(:customer_group, tenant: other_tenant, name: 'RÉGIO', terms: ['MOINHO REGIO'])
      create(:atua_customer, tenant: other_tenant, code: 3783, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', customer_group: other_group)
      create(:atua_expense, tenant: other_tenant, payee_code: 3783, total_cents: 5_500)
    end

    it 'removes only the R$ 55,00 expenses paid to Régio, even when linked to a CT-e' do
      expect(described_class.call(tenant)).to eq(2)

      expect(cascavel_lining.reload.removed_from_atua_at).to be_present
      expect(cuiaba_lining.reload.removed_from_atua_at).to be_present
      expect(tenant.atua_expenses.active).to contain_exactly(regio_unloading, other_payee)
      expect(other_tenant_lining.reload.removed_from_atua_at).to be_nil
    end

    it 'finds nothing left on a second run' do
      described_class.call(tenant)

      expect(described_class.call(tenant)).to eq(0)
    end
  end

  context 'when the Régio group is not activated' do
    let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO'], activated_at: nil) }
    let!(:cascavel) { create(:atua_customer, tenant:, code: 3783, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', customer_group: regio) }
    let!(:lining) { create(:atua_expense, tenant:, payee_code: 3783, total_cents: 5_500) }

    it 'keeps the expenses, since no tarp lining is calculated for the CT-es' do
      expect(described_class.call(tenant)).to eq(0)

      expect(lining.reload.removed_from_atua_at).to be_nil
    end
  end
end
