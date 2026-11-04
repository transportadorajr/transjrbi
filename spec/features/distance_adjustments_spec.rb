require 'rails_helper'

describe 'Distance adjustments' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Ajustes de km', slug: 'distance_adjustments') }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit distance_adjustments_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not register an adjustment' do
      expect do
        page.driver.submit :post, distance_adjustments_path, { distance_adjustment: { transport_document_number: '74120', distance_km: '450' } }
      end.not_to change(DistanceAdjustment, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there is no adjustment' do
      scenario 'shows the empty state message' do
        visit distance_adjustments_path

        expect(DistanceAdjustment.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are adjustments' do
      let!(:applied) do
        create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450'),
                                     applied_at: Time.zone.local(2026, 11, 3, 14, 20))
      end
      let!(:pending) { create(:distance_adjustment, tenant:, transport_document_number: '9870', distance_km: BigDecimal('1210.5')) }
      let!(:stranger) { create(:distance_adjustment, tenant: other_tenant, transport_document_number: '55555') }

      scenario 'lists the adjustments of the tenant from the tax menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Fiscal'
          click_on 'Ajustes de km'
        end

        expect(page).to have_current_path(distance_adjustments_path)
        expect(DistanceAdjustment.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Número do CT-e', 'KM considerado', 'Situação', 'Aplicado em', 'Ações'],
            ['9870', '1.210,50 km', 'Aguardando CT-e', '-', 'Opções Alterar Excluir'],
            ['74120', '450,00 km', 'Aplicado', '03/11/2026 14:20', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Novo Ajuste', href: new_distance_adjustment_path)
        expect(page).to have_link('Importar Planilha', href: '#distanceAdjustmentImportModal')
        expect(page).to have_no_text('55555')
      end

      scenario 'filters the adjustments by status' do
        visit distance_adjustments_path
        select 'Aguardando CT-e', from: 'Situação'
        click_on 'Aplicar Filtros'

        expect(DistanceAdjustment.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Número do CT-e', 'KM considerado', 'Situação', 'Aplicado em', 'Ações'],
            ['9870', '1.210,50 km', 'Aguardando CT-e', '-', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'filters the adjustments by number' do
        visit distance_adjustments_path
        fill_in 'Número do CT-e', with: '741'
        click_on 'Aplicar Filtros'

        expect(DistanceAdjustment.count).to eq(3)
        expect(html_table_to_rows).to eq(
          [
            ['Número do CT-e', 'KM considerado', 'Situação', 'Aplicado em', 'Ações'],
            ['74120', '450,00 km', 'Aplicado', '03/11/2026 14:20', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'does not open an adjustment of another tenant' do
        visit edit_distance_adjustment_path(stranger)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when the transport document is already imported' do
      let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }
      let!(:transport_documents_resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }

      scenario 'registers the adjustment and replaces the distance of the transport document' do
        visit distance_adjustments_path
        click_on 'Novo Ajuste'
        fill_in 'Número do CT-e', with: '74120'
        fill_in 'KM considerado', with: '450,00'

        expect { click_on 'Cadastrar Ajuste' }.to change(DistanceAdjustment, :count).by(1)

        expect(page).to have_current_path(distance_adjustments_path)
        expect(page).to have_text('Ajuste salvo e aplicado ao CT-e 74120.')
        adjustment = DistanceAdjustment.last
        expect(adjustment).to have_attributes(tenant:, transport_document_number: '74120', distance_km: BigDecimal('450'))
        expect(adjustment.applied_at).to be_present
        expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))

        visit transport_document_path(document)

        expect(dl_to_hash('#transport')).to include('Distância (km)' => '450,00 Ajustado manualmente. KM do Atua: 300,00')
      end

      scenario 'shows the errors of an invalid adjustment' do
        visit new_distance_adjustment_path
        fill_in 'Número do CT-e', with: '74120'
        fill_in 'KM considerado', with: '0'

        expect { click_on 'Cadastrar Ajuste' }.not_to change(DistanceAdjustment, :count)

        expect(page).to have_text('KM considerado deve ser maior que 0')
        expect(document.reload.distance_km).to eq(BigDecimal('300'))
      end

      context 'with an applied adjustment' do
        let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('450')) }

        before { DistanceAdjustments::ApplyCommand.call(adjustment) }

        scenario 'changes the distance of the transport document' do
          visit distance_adjustments_path
          within("#distance_adjustment_#{adjustment.id} .inline-actions") { click_on 'Alterar' }
          fill_in 'KM considerado', with: '520,5'

          expect { click_on 'Salvar Alterações' }.not_to change(DistanceAdjustment, :count)

          expect(page).to have_text('Ajuste salvo e aplicado ao CT-e 74120.')
          expect(adjustment.reload.distance_km).to eq(BigDecimal('520.5'))
          expect(document.reload).to have_attributes(distance_km: BigDecimal('520.5'), original_distance_km: BigDecimal('300'))
        end

        scenario 'asks for confirmation and gives the transport document its distance back' do
          visit distance_adjustments_path

          expect(page).to have_css(
            "#distance_adjustment_#{adjustment.id} a[data-turbo-confirm='O CT-e voltará a usar o KM informado pelo Atua. Deseja continuar?']",
          )

          expect { page.driver.submit :delete, distance_adjustment_path(adjustment), {} }.to change(DistanceAdjustment, :count).by(-1)

          expect(page).to have_current_path(distance_adjustments_path)
          expect(page).to have_text('Ajuste excluído. O CT-e voltou a usar o KM informado pelo Atua.')
          expect(document.reload).to have_attributes(distance_km: BigDecimal('300'), original_distance_km: nil, distance_adjusted_at: nil)
        end
      end
    end

    context 'when the transport document was not imported yet' do
      scenario 'registers the adjustment waiting for the transport document' do
        visit new_distance_adjustment_path
        fill_in 'Número do CT-e', with: '74999'
        fill_in 'KM considerado', with: '610'

        expect { click_on 'Cadastrar Ajuste' }.to change(DistanceAdjustment, :count).by(1)

        expect(page).to have_text('Ajuste salvo. O CT-e 74999 ainda não foi importado e receberá o KM na próxima importação.')
        expect(DistanceAdjustment.last).to have_attributes(transport_document_number: '74999', distance_km: BigDecimal('610'), applied_at: nil)
      end
    end

    context 'when importing a spreadsheet' do
      let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }
      let!(:existing) { create(:distance_adjustment, tenant:, transport_document_number: '75300', distance_km: BigDecimal('100')) }

      scenario 'creates and updates the adjustments and reports the invalid rows' do
        path = xlsx_file([%w[CT-e KM], [74_120, 450], [75_300, 280], [74_999, 0]])

        visit distance_adjustments_path
        within('#distanceAdjustmentImportModal') do
          attach_file 'Planilha', path
          expect { click_on 'Importar' }.to change(DistanceAdjustment, :count).by(1)
        end

        expect(page).to have_current_path(distance_adjustments_path)
        expect(page).to have_text('Planilha importada: 1 ajuste(s) criado(s) e 1 atualizado(s); 1 aplicado(s) e 1 aguardando CT-e.')
        expect(page).to have_text('Linha 4: KM considerado deve ser maior que 0.')
        expect(existing.reload.distance_km).to eq(BigDecimal('280'))
        expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
      end

      scenario 'rejects a file that is not an Excel spreadsheet' do
        visit distance_adjustments_path
        within('#distanceAdjustmentImportModal') do
          attach_file 'Planilha', Rails.root.join('Gemfile')
          expect { click_on 'Importar' }.not_to change(DistanceAdjustment, :count)
        end

        expect(page).to have_text('Planilha deve ser uma planilha do Excel (.xlsx, .xls)')
      end
    end
  end

  context 'when an operator without access is signed in' do
    let!(:operator) { create(:user, tenant:, user_type: :operator) }

    before { login_as(operator, scope: :user) }

    scenario 'does not open the screen' do
      visit distance_adjustments_path

      expect(page).to have_current_path(root_path)
      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
    end

    context 'with read access to the adjustments' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }
      let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120') }

      scenario 'lists the adjustments without the management actions' do
        visit distance_adjustments_path

        expect(DistanceAdjustment.count).to eq(1)
        expect(page).to have_no_link('Novo Ajuste')
        expect(page).to have_no_link('Importar Planilha')
        expect(page).to have_no_link('Alterar')
      end

      scenario 'does not import a spreadsheet' do
        file = Rack::Test::UploadedFile.new(xlsx_file([[74_121, 450]]), original_filename: 'km.xlsx')

        expect do
          page.driver.submit :post, import_distance_adjustments_path, { distance_adjustment_import: { file: } }
        end.not_to change(DistanceAdjustment, :count)
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120') }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit distance_adjustments_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NÚMERO DO CT-E')
      expect(page).to have_css('th', text: 'SITUAÇÃO')
      expect(page).to have_no_css('th', text: 'KM CONSIDERADO')
      expect(page).to have_no_css('th', text: 'APLICADO EM')

      click_on 'Ordenar por'
      within('.table-card-header') { click_on 'KM considerado' }

      expect(page).to have_current_path(distance_adjustments_path(sort: :distance_km, direction: :desc))

      within("#distance_adjustment_#{adjustment.id}") do
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_distance_adjustment_path(adjustment))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
