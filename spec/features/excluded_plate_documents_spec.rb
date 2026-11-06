require 'rails_helper'

describe 'Records of an excluded plate' do
  let!(:tenant) { create(:tenant) }
  let!(:owner) { create(:user, tenant:, user_type: :owner) }
  let!(:freight_billing_resource) { create(:resource, name: 'Faturamento', slug: 'freight_billing', writable: false) }
  let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:manifests_resource) { create(:resource, name: 'Manifestos', slug: 'manifests', writable: false) }
  let!(:favor_document) do
    create(:atua_transport_document, tenant:, plate: 'BAM2A26', number: '71820', document_kind: 'cte', freight_cents: 90_000_000)
  end
  let!(:fleet_document) do
    create(:atua_transport_document, tenant:, plate: 'RHJ4E07', number: '71899', document_kind: 'cte', freight_cents: 100_000)
  end
  let!(:favor_manifest) { create(:atua_manifest, tenant:, number: '9001', plate: 'BAM2A26') }
  let!(:fleet_manifest) { create(:atua_manifest, tenant:, number: '9002', plate: 'RHJ4E07') }

  before do
    create(:atua_manifest_document, tenant:, manifest_code: favor_manifest.code, transport_document_number: favor_document.number,
                                    transport_document_series: favor_document.series, branch_name: favor_document.branch_name)
    create(:atua_manifest_document, tenant:, manifest_code: fleet_manifest.code, transport_document_number: fleet_document.number,
                                    transport_document_series: fleet_document.series, branch_name: fleet_document.branch_name)
    Atua::DiscardExcludedPlatesCommand.call(tenant)
    login_as(owner, scope: :user)
  end

  scenario 'leaves them out of the freight billing totals' do
    visit freight_billing_path(start_date: '2026-10-01', end_date: '2026-10-31')

    expect(page).to have_text('1.000,00')
    expect(page).to have_no_text('900.000,00')
  end

  scenario 'leaves them out of the transport documents listing' do
    visit transport_documents_path

    expect(page).to have_text('71899')
    expect(page).to have_no_text('71820')
    expect(page).to have_no_text('BAM2A26')
  end

  scenario 'returns not found on the show screen of the document' do
    visit transport_document_path(favor_document)

    expect(page.status_code).to eq(404)
  end

  scenario 'leaves them out of the manifests listing' do
    visit manifests_path

    expect(page).to have_text('9002')
    expect(page).to have_no_text('9001')
  end
end
