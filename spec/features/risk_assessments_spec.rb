require 'rails_helper'

describe 'Risk assessments', :hr do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:hr_resource) { create(:resource, name: 'Módulo de RH', slug: 'hr', writable: false) }
  let!(:resource) { create(:resource, name: 'Gerenciadoras de risco', slug: 'risk_assessments') }
  let!(:employees_resource) { create(:resource, name: 'Funcionários', slug: 'employees') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE SILVA', legal_id: '52998224725') }
  let!(:ana) { create(:employee, tenant:, name: 'ANA PAULA', legal_id: '11144477735', company_type: 'mme') }

  around { |example| travel_to(Time.zone.local(2026, 11, 24, 10)) { example.run } }

  context 'without a signed in user', flipper: :hr do
    scenario 'redirects the listing to the login screen' do
      visit risk_assessments_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in', flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when there are risk assessments' do
      let!(:jose_apisul) do
        create(:risk_assessment, employee: jose, provider_type: 'apisul', score: 40, valid_until: Date.new(2027, 1, 20), notes: 'RENOVAR EM JANEIRO')
      end
      let!(:jose_opentech) do
        create(:risk_assessment, employee: jose, provider_type: 'opentech', status_type: 'not_recommended', score: nil, valid_until: nil)
      end
      let!(:ana_apisul) do
        create(:risk_assessment, employee: ana, provider_type: 'apisul', status_type: 'recommended', score: 160, valid_until: Date.new(2027, 5, 11))
      end

      before { create(:risk_assessment, employee: create(:employee, tenant: other_tenant, name: 'FUNCIONÁRIO DE OUTRA')) }

      scenario 'lists the risk assessments from the HR menu by employee name' do
        visit risk_assessments_path
        within('.sidebar-desktop') do
          click_on 'Seguros'
          click_on 'Gerenciadoras de risco'
        end

        expect(page).to have_current_path(risk_assessments_path)
        expect(RiskAssessment.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Gerenciadora', 'Score', 'Validade', 'Situação', 'Ações'],
            ['ANA PAULA', 'Apisul', '160', '11/05/2027', 'Recomendado', 'Opções Alterar Excluir'],
            ['JOSE SILVA', 'Apisul', '40', '20/01/2027', 'Não recomendado', 'Opções Alterar Excluir'],
            ['JOSE SILVA', 'Opentech', '-', '-', 'Não recomendado', 'Opções Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Cadastrar Pesquisa', href: new_risk_assessment_path)
        expect(page).to have_no_text('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'filters the risk assessments by employee, provider and status' do
        visit risk_assessments_path(name: 'jose', provider_type: 'opentech')

        expect(RiskAssessment.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Gerenciadora', 'Score', 'Validade', 'Situação', 'Ações'],
            ['JOSE SILVA', 'Opentech', '-', '-', 'Não recomendado', 'Opções Alterar Excluir'],
          ],
        )

        visit risk_assessments_path(status_type: 'recommended', company_type: 'mme')

        expect(html_table_to_rows).to eq(
          [
            ['Funcionário', 'Gerenciadora', 'Score', 'Validade', 'Situação', 'Ações'],
            ['ANA PAULA', 'Apisul', '160', '11/05/2027', 'Recomendado', 'Opções Alterar Excluir'],
          ],
        )
      end

      scenario 'sorts the risk assessments by validity' do
        visit risk_assessments_path(sort: 'valid_until', direction: 'asc')

        expect(RiskAssessment.count).to eq(4)
        expect(html_table_to_rows.drop(1).map { |row| row.first(4) }).to eq(
          [
            ['JOSE SILVA', 'Apisul', '40', '20/01/2027'],
            ['ANA PAULA', 'Apisul', '160', '11/05/2027'],
            ['JOSE SILVA', 'Opentech', '-', '-'],
          ],
        )
      end

      scenario 'edits a risk assessment' do
        visit risk_assessments_path
        within("#risk_assessment_#{jose_apisul.id}") { click_on 'Alterar', match: :first }

        expect(page).to have_select('risk_assessment[employee_id]', selected: 'JOSE SILVA', disabled: true)
        fill_in 'Score', with: '160'
        fill_in 'Validade', with: '2027-07-20'

        expect { click_on 'Salvar Alterações' }.not_to change(RiskAssessment, :count)

        expect(page).to have_text('Pesquisa atualizada com sucesso.')
        expect(jose_apisul.reload).to have_attributes(employee: jose, provider_type: 'apisul', status_type: 'recommended', score: 160,
                                                      valid_until: Date.new(2027, 7, 20), notes: 'RENOVAR EM JANEIRO')
      end

      scenario 'deletes a risk assessment' do
        visit risk_assessments_path

        expect { page.driver.submit :delete, risk_assessment_path(jose_opentech), {} }.to change(RiskAssessment, :count).by(-1)

        expect(page).to have_text('Pesquisa excluída com sucesso.')
        expect(RiskAssessment.exists?(jose_opentech.id)).to be(false)
      end

      scenario 'shows the risk assessments on the employee page' do
        visit employee_path(jose)

        within('#risk_assessments') do
          expect(html_table_to_rows).to eq(
            [
              ['Gerenciadora', 'Score', 'Validade', 'Situação', 'Ações'],
              ['Apisul', '40', '20/01/2027', 'Não recomendado', 'Opções Alterar Excluir'],
              ['Opentech', '-', '-', 'Não recomendado', 'Opções Alterar Excluir'],
            ],
          )
          expect(page).to have_link('Cadastrar pesquisa', href: new_risk_assessment_path(employee_id: jose.id))
        end
      end

      scenario 'exports the risk assessments to PDF' do
        visit risk_assessments_path(format: :pdf)

        text = PDF::Inspector::Text.analyze(page.body).strings.join
        expect(page.response_headers['Content-Type']).to include('application/pdf')
        expect(RiskAssessment.count).to eq(4)
        expect(text).to include('Relatório das Gerenciadoras de Risco', 'ANA PAULA', 'JOSE SILVA', '20/01/2027', 'Não recomendado', 'RENOVAR EM JANEIRO')
        expect(text).not_to include('FUNCIONÁRIO DE OUTRA')
      end

      scenario 'exports the risk assessments to Excel', :xlsx_service, flipper: { hr: :tenant, xlsx_export: :tenant } do
        visit risk_assessments_path(provider_type: 'apisul', name: 'jose')
        click_on 'Exportar Excel'

        expect(page.response_headers['Content-Disposition']).to include('attachment', "gerenciadoras-de-risco-#{Date.current.iso8601}.xlsx")
        expect(downloaded_xlsx_rows.first).to eq(
          ['Funcionário', 'Gerenciadora', 'Situação', 'Score', 'Validade', 'Observações', 'Criado em', 'Atualizado em'],
        )
        expect(downloaded_xlsx_rows.drop(1).map { |row| row.first(6) }).to eq(
          [['JOSE SILVA', 'Apisul', 'Não recomendado', 40, Date.new(2027, 1, 20), 'RENOVAR EM JANEIRO']],
        )
      end
    end

    context 'when there are no risk assessments' do
      scenario 'shows the empty listing' do
        visit risk_assessments_path

        expect(RiskAssessment.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    scenario 'registers a risk assessment from the employee page' do
      visit employee_path(ana)
      within('#risk_assessments') { click_on 'Cadastrar pesquisa' }

      select 'Opentech', from: 'Gerenciadora'
      select 'Não recomendado', from: 'Situação'
      fill_in 'Observações', with: 'Pendência na CNH'

      expect { click_on 'Cadastrar Pesquisa' }.to change(RiskAssessment, :count).by(1)

      expect(page).to have_current_path(risk_assessments_path)
      expect(page).to have_text('Pesquisa cadastrada com sucesso.')
      expect(RiskAssessment.last).to have_attributes(tenant:, employee: ana, provider_type: 'opentech', status_type: 'not_recommended', score: nil,
                                                     valid_until: nil, notes: 'Pendência na CNH')
    end

    scenario 'shows the validation errors of the risk assessment' do
      create(:risk_assessment, employee: ana, provider_type: 'apisul')
      visit new_risk_assessment_path(employee_id: ana.id)

      select 'Apisul', from: 'Gerenciadora'

      expect { click_on 'Cadastrar Pesquisa' }.not_to change(RiskAssessment, :count)

      expect(page).to have_text('Gerenciadora já tem uma pesquisa cadastrada para este funcionário')
    end
  end

  context 'when the owner is signed in on a phone', :js, flipper: :hr do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before do
      use_mobile_screen
      login_as(owner, scope: :user)
    end

    scenario 'picks the employee and registers a risk assessment' do
      visit new_risk_assessment_path

      within('#risk_assessment_employee_select') do
        find('.select2-trigger').click
        find('.select2-search').fill_in(with: 'jose')
        find('.select2-option', text: 'JOSE SILVA').click
      end
      select 'Apisul', from: 'Gerenciadora'
      fill_in 'Score', with: '158'

      expect { click_on 'Cadastrar Pesquisa' }.to change(RiskAssessment, :count).by(1)

      expect(page).to have_text('Pesquisa cadastrada com sucesso.')
      expect(page).to have_css('td', text: 'JOSE SILVA')
      expect(page).to have_no_css('td', text: '158')
      expect(RiskAssessment.last).to have_attributes(employee: jose, provider_type: 'apisul', score: 158)
    end
  end
end
