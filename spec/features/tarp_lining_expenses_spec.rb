require 'rails_helper'

describe 'Tarp lining paid to Régio' do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, tenant:, user_type: :owner) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
  let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }
  let!(:regio) { create(:customer_group, tenant:, name: 'RÉGIO', terms: ['MOINHO REGIO']) }
  let!(:cuiaba) { create(:atua_customer, tenant:, code: 7684, name: 'MOINHO REGIO ALIMENTOS S/A - CUIABA', customer_group: regio) }
  let!(:cascavel) { create(:atua_customer, tenant:, code: 3783, name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', customer_group: regio) }
  let!(:transport_document) do
    create(:atua_transport_document, tenant:, number: '77001', taker_code: 7684, taker_name: 'MOINHO REGIO ALIMENTOS S/A - CUIABA',
                                     freight_cents: 500_000, icms_cents: 0, toll_cents: 0)
  end

  before do
    create(:atua_expense, tenant:, code: 590_501, posted_at: Time.zone.local(2026, 10, 3, 15), posted_on: Date.new(2026, 10, 3),
                          history_code: 72, history_name: 'CHAPA / CARGA, DESCARGA', payee_code: 3783,
                          payee_name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', description: 'LONAS PAGA A MOINHO REGIO', total_cents: 5_500,
                          cost_object: transport_document)
    create(:atua_expense, tenant:, code: 590_502, posted_at: Time.zone.local(2026, 10, 3, 16), posted_on: Date.new(2026, 10, 3),
                          history_code: 72, history_name: 'CHAPA / CARGA, DESCARGA', payee_code: 3783,
                          payee_name: 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', total_cents: 7_000, cost_object: transport_document)
    Atua::DiscardTarpLiningExpensesCommand.call(tenant)
    FreightExpenses::CalculateTarpLiningCommand.call(tenant)
    login_as(owner, scope: :user)
  end

  scenario 'discounts the tarp lining of the CT-e only once' do
    visit transport_document_path(transport_document)

    expect(Atua::Expense.count).to eq(2)
    expect(html_table_to_rows(table: find_by_id('transport_document_expenses'))).to eq(
      [
        ['Histórico', 'Lançado em', 'Favorecido', 'Valor total'],
        ['CHAPA / CARGA, DESCARGA', '03/10/2026', 'MOINHO REGIO ALIMENTOS S/A - CASCAVEL', 'R$ 70,00'],
      ],
    )
    expect(dl_to_hash('#transport_document_net_freight')).to include(
      '(−) Forro de lona' => 'R$ 55,00',
      '(−) Despesas do frete na Atua' => 'R$ 70,00',
    )
  end
end
