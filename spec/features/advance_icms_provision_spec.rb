require 'rails_helper'

describe 'Advance ICMS provision' do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, tenant:, user_type: :owner) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
  let!(:expenses_resource) { create(:resource, name: 'Despesas', slug: 'expenses', writable: false) }
  let!(:customer_groups_resource) { create(:resource, name: 'Grupos de clientes', slug: 'customer_groups') }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', terms: ['GERDAU'], pays_advance_icms_at: Time.zone.local(2026, 11, 1)) }
  let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, name: 'GERDAU ACOS LONGOS S.A', customer_group: gerdau) }
  let!(:transport_document) do
    create(:atua_transport_document, tenant:, number: '75845', cfop: 6932, taker_code: 601, taker_name: 'GERDAU ACOS LONGOS S.A',
                                     origin_city: 'SAO PAULO', origin_state: 'SP', issued_at: Time.zone.local(2026, 11, 25, 13, 15),
                                     freight_cents: 72_343, weight_freight_cents: 63_662, icms_cents: 8_681, toll_cents: 0)
  end

  before do
    FreightExpenses::CalculateAdvanceIcmsCommand.call(tenant)
    login_as(owner, scope: :user)
  end

  scenario 'discounts the ICMS of a CT-e still without a guide from its net freight' do
    visit transport_document_path(transport_document)

    expect(FreightExpense.advance_icms.count).to eq(1)
    expect(dl_to_hash('#transport_document_net_freight')).to include(
      'Frete bruto' => 'R$ 723,43',
      '(−) ICMS antecipado com guia pendente' => 'R$ 86,81',
      '(−) Despesas do frete na Atua' => 'R$ 0,00',
      '(=) Frete líquido' => 'R$ 636,62',
    )
  end

  scenario 'lists the provision with the other freight expenses' do
    visit freight_expenses_path(kind: 'advance_icms')

    expect(FreightExpense.count).to eq(1)
    expect(html_table_to_rows).to eq(
      [
        ['CT-e', 'Emitido em', 'Tomador', 'Tipo', 'Regra ou custo', 'Base de cálculo', 'Taxa', 'Valor', 'Ações'],
        ['75845', '25/11/2026 13:15', 'GERDAU ACOS LONGOS S.A', 'Provisão de ICMS antecipado', 'ICMS do CT-e até a guia ser lançada na Atua',
         'R$ 86,81', '-', 'R$ 86,81', ''],
      ],
    )
  end

  context 'when the guide of the CT-e is imported from Atua' do
    let!(:guide) do
      create(:atua_expense, tenant:, code: 590_601, history_code: 503, history_name: 'ICMS ANTECIPADO', document_number: '75845',
                            transport_document_code: transport_document.code, transport_document_number: '75845', total_cents: 8_681)
    end

    scenario 'replaces the provision by the guide once it is linked, keeping the net freight' do
      Atua::LinkExpensesJob.perform_now(tenant.id)
      visit transport_document_path(transport_document)

      expect(guide.reload.cost_object).to eq(transport_document)
      expect(FreightExpense.advance_icms.count).to eq(0)
      expect(dl_to_hash('#transport_document_net_freight')).to include(
        '(−) ICMS antecipado com guia pendente' => 'R$ 0,00',
        '(−) Despesas do frete na Atua' => 'R$ 86,81',
        '(=) Frete líquido' => 'R$ 636,62',
      )
    end
  end

  scenario 'recalculates the freight expenses when the group stops having the guides paid by the carrier' do
    visit edit_customer_group_path(gerdau)

    uncheck 'JR paga a guia de ICMS antecipado'

    expect { click_on 'Salvar Alterações' }
      .to have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id).and(change(CustomerGroup, :count).by(0))
    expect(gerdau.reload.pays_advance_icms_at).to be_nil
  end

  scenario 'does not recalculate the freight expenses when the rule of the group is kept' do
    visit edit_customer_group_path(gerdau)

    fill_in 'Nome', with: 'GERDAU SP'

    expect { click_on 'Salvar Alterações' }.not_to have_enqueued_job(FreightExpenses::CalculateJob)
    expect(CustomerGroup.count).to eq(1)
    expect(gerdau.reload.name).to eq('GERDAU SP')
    expect(gerdau.pays_advance_icms_at).to be_present
  end
end
