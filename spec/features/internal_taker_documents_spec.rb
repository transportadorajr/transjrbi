require 'rails_helper'

describe 'Documents taken by Transjr' do
  let!(:tenant) { create(:tenant) }
  let!(:admin) { create(:user, tenant:, user_type: :admin) }
  let!(:freight_billing_resource) { create(:resource, name: 'Faturamento de fretes', slug: 'freight_billing', writable: false) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:manifests_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
  let!(:taker) { create(:atua_customer, tenant:, name: 'TRANSJR TRANSPORTADORA LTDA', document_digits: '10212838000100') }
  let!(:customer) { create(:atua_customer, tenant:, name: 'USIMINAS') }
  let!(:internal_document) do
    create(:atua_transport_document, tenant:, taker_code: taker.code, taker_name: taker.name, number: '74130', document_kind: 'ce',
                                     freight_cents: 90_000_000)
  end
  let!(:billed_document) do
    create(:atua_transport_document, tenant:, taker_code: customer.code, taker_name: customer.name, number: '74199', document_kind: 'ce',
                                     freight_cents: 100_000)
  end
  let!(:manifest) { create(:atua_manifest, tenant:, code: 41_236) }
  let!(:internal_manifest_document) do
    create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74130', transport_document_series: 1,
                                    branch_name: internal_document.branch_name)
  end
  let!(:billed_manifest_document) do
    create(:atua_manifest_document, tenant:, manifest_code: 41_236, transport_document_number: '74199', transport_document_series: 1,
                                    branch_name: billed_document.branch_name)
  end

  before do
    Atua::DiscardInternalTakerDocumentsCommand.call(tenant)
    login_as(admin, scope: :user)
  end

  scenario 'leaves them out of the freight billing totals' do
    visit freight_billing_path(start_date: '2026-10-01', end_date: '2026-10-31')

    expect(page).to have_text('1.000,00')
    expect(page).to have_no_text('900.000,00')
    expect(page).to have_no_text(taker.name)
  end

  scenario 'leaves them out of the transport documents listing' do
    visit transport_documents_path

    expect(page).to have_text('74199')
    expect(page).to have_no_text('74130')
  end

  scenario 'returns not found on the show screen of the document' do
    visit transport_document_path(internal_document)

    expect(page.status_code).to eq(404)
  end

  scenario 'leaves them out of the documents of the manifest' do
    visit manifest_path(manifest)

    expect(page).to have_text('74199')
    expect(page).to have_no_text('74130')
  end
end
