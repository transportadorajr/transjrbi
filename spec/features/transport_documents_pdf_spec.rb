require 'rails_helper'

describe 'Transport documents PDF report' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:freight_expenses_resource) { create(:resource, name: 'Despesas de frete', slug: 'freight_expenses', writable: false) }

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are transport documents' do
      let!(:authorized) do
        create(:atua_transport_document, tenant:, number: '74130', sender_name: 'USIMINAS & CIA "MG"', posted_on: Date.new(2026, 10, 1),
                                         origin_city: 'Ipatinga', origin_state: 'MG', destination_city: 'Betim', destination_state: 'MG',
                                         plate: 'EXU0F72', freight_cents: 55_504)
      end
      let!(:other_freight) do
        create(:atua_transport_document, tenant:, number: '74135', sender_name: 'GERDAU', posted_on: Date.new(2026, 10, 3), plate: 'RHJ4E07',
                                         freight_cents: 120_000)
      end
      let!(:canceled) do
        create(:atua_transport_document, tenant:, number: '74131', posted_on: Date.new(2026, 10, 5), canceled_at: Time.zone.local(2026, 10, 5, 9))
      end
      let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '74133') }

      scenario 'exports the valid transport documents of the tenant on a landscape page' do
        travel_to Time.zone.local(2026, 11, 6, 14, 30) do
          visit transport_documents_path(format: :pdf)
        end

        expect(page.status_code).to eq(200)
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(page.response_headers['Content-Disposition']).to include('inline')
        expect(Atua::TransportDocument.count).to eq(4)

        width, height = PDF::Inspector::Page.analyze(page.body).pages.first[:size]
        expect(width).to be > height

        text = pdf_text
        expect(text).to include('Relatório de CT-es')
        expect(text).to include('Número', 'Remetente', 'Dt Emissão', 'Origem / Destino', 'Placa', 'Grupo de clientes', 'Motorista',
                                'Frete bruto', 'Frete líquido')
        expect(text).to include('74130', 'USIMINAS & CIA "MG"', '01/10/2026', 'Ipatinga/MG → Betim/MG', 'EXU0F72', 'R$ 555,04')
        expect(text).to include('74135', 'GERDAU', '03/10/2026', 'RHJ4E07', 'R$ 1.200,00')
        expect(text).to include('2 registros listados.')
        expect(text).to include('Gerado em 06/11/2026 14:30.')
        expect(text).to include('Página 1')
        expect(text).not_to include('74131')
        expect(text).not_to include('74133')
      end

      scenario 'exports only the transport documents that match the filters' do
        visit transport_documents_path(format: :pdf, number: '74130')

        text = pdf_text
        expect(text).to include('74130')
        expect(text).to include('1 registro listado.')
        expect(text).not_to include('74135')
      end

      scenario 'links the export button to the PDF with the applied filters' do
        visit transport_documents_path(number: '74130')

        expect(page).to have_link('Exportar PDF', href: transport_documents_path(format: :pdf, number: '74130'))
      end
    end
  end

  context 'when an operator without access to the freight expenses is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }
    let!(:transport_document) { create(:atua_transport_document, tenant:, number: '74130', freight_cents: 55_504) }

    before { login_as(operator, scope: :user) }

    scenario 'exports the report without the net freight column' do
      visit transport_documents_path(format: :pdf)

      text = pdf_text
      expect(text).to include('74130', 'Frete bruto', 'R$ 555,04')
      expect(text).not_to include('Frete líquido')
    end
  end

  context 'when an operator without access to the transport documents is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    scenario 'is sent back with an access denied message' do
      visit transport_documents_path(format: :pdf)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end
  end

  def pdf_text
    PDF::Inspector::Text.analyze(page.body).strings.join
  end
end
