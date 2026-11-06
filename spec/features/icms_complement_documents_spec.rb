require 'rails_helper'

describe 'Value complements of ICMS' do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, tenant:, user_type: :owner) }
  let!(:freight_billing_resource) { create(:resource, name: 'Faturamento', slug: 'freight_billing', writable: false) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }
  let!(:original) do
    create(:atua_transport_document, tenant:, number: '74754', taker_name: 'RUDOLF SIZING', freight_cents: 427_577, icms_cents: 45_577)
  end
  let!(:icms_complement) do
    create(:atua_transport_document, tenant:, number: '74777', taker_name: 'RUDOLF SIZING', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                     complemented_number: '74754', complemented_transport_document: original, freight_cents: 6_514,
                                     weight_freight_cents: 0, icms_cents: 6_514)
  end
  let!(:freight_complement) do
    create(:atua_transport_document, tenant:, number: '74778', taker_name: 'RUDOLF SIZING', issue_kind: Atua::TransportDocument::VALUE_COMPLEMENT,
                                     complemented_number: '74754', complemented_transport_document: original, freight_cents: 73_600,
                                     icms_cents: 8_832)
  end

  before do
    Atua::DiscardIcmsComplementsCommand.call(tenant)
    login_as(owner, scope: :user)
  end

  scenario 'leaves them out of the transport documents listing' do
    visit transport_documents_path

    expect(page).to have_text('74754')
    expect(page).to have_text('74778')
    expect(page).to have_no_text('74777')
  end

  scenario 'leaves them out of the net freight of the complemented document' do
    visit transport_document_path(original)

    expect(dl_to_hash('#transport_document_net_freight')).to include(
      'Frete bruto' => 'R$ 4.275,77',
      '(+) Complementos de valores' => 'R$ 736,00',
      '(=) Frete líquido' => 'R$ 5.011,77',
    )
  end

  scenario 'returns not found on the show screen of the complement' do
    visit transport_document_path(icms_complement)

    expect(page.status_code).to eq(404)
  end

  scenario 'leaves them out of the freight billing totals' do
    visit freight_billing_path(start_date: '2026-10-01', end_date: '2026-10-31')

    expect(page).to have_text('5.011,77')
    expect(page).to have_no_text('5.076,91')
  end
end
