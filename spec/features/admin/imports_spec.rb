require 'rails_helper'

describe 'Admin Atua imports', :admin do
  let(:now) { Time.zone.local(2026, 10, 14, 12) }
  let!(:admin_user) { create(:admin_user) }
  let!(:tenant) { create(:tenant, trade_name: 'TransJR') }
  let!(:other_tenant) { create(:tenant, trade_name: 'Outra') }

  before { travel_to(now) }

  context 'with imports of two tenants', flipper: { atua_import: :tenant } do
    let!(:transport_documents) do
      create(:atua_import, :with_file, tenant:, report_type: 'transport_documents', status_type: 'succeeded',
                                       started_at: now - 1.hour, finished_at: now - 1.hour + 125.seconds, rows_read: 420,
                                       inserted_count: 420, created_at: now - 3.hours)
    end
    let!(:manifests) do
      create(:atua_import, :with_file, tenant:, report_type: 'manifests', status_type: 'failed', error_type: 'layout',
                                       error_message: 'O relatório veio sem as colunas obrigatórias.', started_at: now - 2.hours,
                                       finished_at: now - 2.hours + 3.seconds, created_at: now - 2.hours)
    end
    let!(:customers) do
      create(:atua_import, tenant: other_tenant, report_type: 'customers', status_type: 'failed', error_type: 'authentication',
                           error_message: 'A Atua recusou o login.', start_date: nil, end_date: nil, started_at: now - 1.hour,
                           finished_at: now - 1.hour + 1.second, created_at: now - 1.hour)
    end
    let!(:expenses) do
      create(:atua_import, tenant:, report_type: 'expenses', status_type: 'running', started_at: now - 10.minutes,
                           created_at: now - 10.minutes)
    end
    let!(:vehicles) do
      create(:atua_import, tenant:, report_type: 'vehicles', status_type: 'succeeded', start_date: nil, end_date: nil,
                           started_at: now - 3.days, finished_at: now - 3.days, created_at: now - 3.days)
    end

    before { sign_in_admin(admin_user) }

    scenario 'lists the imports with their counts, duration and errors' do
      visit admin_root_path

      expect(page).to have_current_path(admin_root_path)
      expect(Atua::Import.count).to eq(5)
      expect(html_table_to_rows(table: find('table'))).to eq(
        [
          ['Relatório', 'Período', 'Situação', 'Contagens', 'Duração', 'Erro', 'Ações'],
          ['Despesas TransJR', '01/10/2026 a 13/10/2026', 'Em andamento', '0 lidas · 0 inseridas · 0 atualizadas · 0 removidas', '-', '-', '-'],
          ['Clientes Outra Exige ação: Login na Atua', 'Cadastro completo', 'Falhou', '0 lidas · 0 inseridas · 0 atualizadas · 0 removidas',
           '0:00:01', 'A Atua recusou o login.', '-'],
          ['Manifestos TransJR Exige ação: Layout do relatório', '01/10/2026 a 13/10/2026', 'Falhou',
           '0 lidas · 0 inseridas · 0 atualizadas · 0 removidas', '0:00:03', 'O relatório veio sem as colunas obrigatórias.',
           'Opções Baixar arquivo Reprocessar'],
          ['Conhecimentos de transporte TransJR', '01/10/2026 a 13/10/2026', 'Concluída',
           '420 lidas · 420 inseridas · 0 atualizadas · 0 removidas', '0:02:05', '-', 'Opções Baixar arquivo Reprocessar'],
          ['Veículos TransJR', 'Cadastro completo', 'Concluída', '0 lidas · 0 inseridas · 0 atualizadas · 0 removidas', '0:00:00', '-', '-'],
        ],
      )
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 5', 'Concluídas 2', 'Com falha 2', 'Em andamento 1'])
      expect(page).to have_text('5 registros')
    end

    scenario 'highlights the failures that require action' do
      visit admin_imports_path

      within('#action-required') do
        expect(page).to have_text('Importações que exigem ação')
        expect(all('li').map { |item| item.text.squish }).to eq(
          [
            'TransJR · Manifestos · Layout do relatório O relatório veio sem as colunas obrigatórias.',
            'Outra · Clientes · Login na Atua A Atua recusou o login.',
          ],
        )
      end
    end

    scenario 'shows the flag and the last success of each report by tenant' do
      visit admin_imports_path

      within("#atua_status_tenant_#{tenant.id}") do
        expect(page).to have_text('Importação ligada')
        expect(dl_to_hash).to eq(
          'Conhecimentos de transporte' => '14 de outubro, 11:02',
          'Manifestos' => 'Nunca',
          'Despesas' => 'Nunca',
          'Clientes' => 'Nunca',
          'Veículos' => '11 de outubro, 12:00',
        )
        expect(all('dt.report-freshness-late').map(&:text)).to eq(%w[Manifestos Despesas Clientes Veículos])
      end
      within("#atua_status_tenant_#{other_tenant.id}") do
        expect(page).to have_text('Importação desligada')
        expect(page).to have_no_css('.report-freshness-late')
      end
    end

    scenario 'filters the imports by tenant, report, status and period' do
      visit admin_imports_path
      select 'TransJR', from: 'Empresa'
      select 'Manifestos', from: 'Relatório'
      select 'Falhou', from: 'Situação'
      fill_in 'Período a partir de', with: '2026-10-01'
      fill_in 'Período até', with: '2026-10-13'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows(table: find('table')).drop(1).map(&:first)).to eq(['Manifestos TransJR Exige ação: Layout do relatório'])
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 1', 'Concluídas 0', 'Com falha 1', 'Em andamento 0'])
    end

    scenario 'filters the registries by the day they were imported' do
      visit admin_imports_path(start_date: '2026-10-14', end_date: '2026-10-14')

      expect(html_table_to_rows(table: find('table')).drop(1).map(&:first)).to eq(['Clientes Outra Exige ação: Login na Atua'])
    end

    scenario 'shows the empty state when nothing matches the filters' do
      visit admin_imports_path(status: 'pending')

      expect(page).to have_text('Nenhum registro encontrado')
      expect(page).to have_no_table
    end

    scenario 'downloads the file of an import' do
      visit admin_imports_path
      within("#atua_import_#{manifests.id}") { first(:link, 'Baixar arquivo').click }

      expect(page.response_headers['Content-Disposition']).to include('attachment', 'rel_ctrc_detalhado.xls')
      expect(page.body).to eq('xls')
    end

    scenario 'enqueues the reprocessing of an import' do
      expect { page.driver.submit :post, reprocess_admin_import_path(manifests), {} }
        .to have_enqueued_job(Atua::ReprocessImportJob).with(manifests.id)

      expect(page).to have_current_path(admin_imports_path)
      expect(page).to have_text('Reprocessamento enfileirado.')
      expect(manifests.reload.status_type).to eq('failed')
    end

    scenario 'refuses to reprocess an import without file' do
      expect { page.driver.submit :post, reprocess_admin_import_path(customers), {} }
        .not_to have_enqueued_job(Atua::ReprocessImportJob)

      expect(page).to have_text('A importação não tem arquivo para reprocessar.')
    end

    scenario 'enqueues the import of a report without running it in the request' do
      visit admin_imports_path
      click_on 'Importar relatório'
      select 'Outra', from: 'Empresa'
      select 'Despesas', from: 'Relatório'
      fill_in 'Data inicial', with: '2026-10-01'
      fill_in 'Data final', with: '2026-10-14'

      expect { click_on 'Enfileirar importação' }
        .to have_enqueued_job(Atua::ImportReportJob).with(other_tenant.id, 'expenses', Date.new(2026, 10, 1), Date.new(2026, 10, 14))
        .and(not_change(Atua::Import, :count))

      expect(page).to have_current_path(admin_imports_path)
      expect(page).to have_text('Importação enfileirada. Ela roda em segundo plano e aparece no histórico ao começar.')
    end

    scenario 'shows the errors of an invalid import request' do
      visit new_admin_import_path
      select 'Despesas', from: 'Relatório'
      fill_in 'Data inicial', with: ''
      fill_in 'Data final', with: ''

      expect { click_on 'Enfileirar importação' }.not_to have_enqueued_job(Atua::ImportReportJob)

      expect(page).to have_text('Empresa não pode ficar em branco, Data inicial não pode ficar em branco e Data final não pode ficar em branco')
    end
  end

  context 'with a tenant to load', flipper: { atua_import: :tenant } do
    before { sign_in_admin(admin_user) }

    scenario 'enqueues the initial load chosen on the screen' do
      visit admin_imports_path
      click_on 'Carga inicial'
      select 'TransJR', from: 'Empresa'
      fill_in 'Data de início', with: '2025-01-01'

      expect { click_on 'Iniciar carga inicial' }
        .to have_enqueued_job(Atua::InitialLoadJob).with(tenant.id, Date.new(2025, 1, 1))
        .and(not_have_enqueued_job(Atua::ImportReportJob))

      expect(page).to have_current_path(admin_imports_path)
      expect(page).to have_text('Carga inicial de TransJR enfileirada.')
    end

    scenario 'refuses an initial load starting in the future' do
      visit new_admin_initial_load_path
      select 'TransJR', from: 'Empresa'
      fill_in 'Data de início', with: '2026-10-15'

      expect { click_on 'Iniciar carga inicial' }.not_to have_enqueued_job(Atua::InitialLoadJob)

      expect(page).to have_text('Data de início não pode ser posterior a hoje')
    end
  end

  context 'when the screen is opened on a phone', :js, flipper: { atua_import: :tenant } do
    let!(:import) do
      create(:atua_import, :with_file, tenant:, report_type: 'manifests', status_type: 'failed', error_type: 'layout',
                                       error_message: 'O relatório veio sem as colunas obrigatórias.', finished_at: now)
    end

    before { sign_in_admin(admin_user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit admin_imports_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'RELATÓRIO')
      expect(page).to have_css('th', text: 'SITUAÇÃO')
      expect(page).to have_no_css('th', text: 'PERÍODO')
      expect(page).to have_no_css('th', text: 'CONTAGENS')
      expect(page).to have_css('#action-required', text: 'TransJR · Manifestos · Layout do relatório')

      within("#atua_import_#{import.id}") do
        expect(page).to have_text('Exige ação: Layout do relatório')
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        expect(page).to have_link('Baixar arquivo')
        expect(page).to have_link('Reprocessar')
      end

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    scenario 'stacks the header actions on the phone' do
      visit admin_imports_path
      use_mobile_screen

      expect(page).to have_link('Carga inicial')
      expect(page).to have_link('Importar relatório')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      click_on 'Carga inicial'

      expect(page).to have_current_path(new_admin_initial_load_path)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
