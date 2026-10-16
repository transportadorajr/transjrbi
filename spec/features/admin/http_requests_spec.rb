require 'rails_helper'

describe 'Admin HTTP requests', :admin do
  let(:now) { Time.zone.local(2026, 10, 14, 12) }
  let!(:admin_user) { create(:admin_user) }
  let!(:tenant) { create(:tenant, trade_name: 'TransJR') }

  before { travel_to(now) }

  context 'when the visitor is not signed in' do
    scenario 'redirects to the login screen' do
      visit admin_http_requests_path

      expect(page).to have_current_path(admin_login_path)
    end
  end

  context 'with requests of both integrations' do
    let!(:import) { create(:atua_import, tenant:, report_type: 'customers') }
    let!(:login) do
      create(:admin_http_request, integration_type: 'atua', tenant:, atua_import: import, http_method: 'POST',
                                  url: 'https://atua.example.test/adm/login.php', status_code: 302, status_message: 'Found',
                                  request_headers: { 'content-type' => 'application/x-www-form-urlencoded', 'cookie' => 'PHPSESSID=[FILTERED]' },
                                  request_body: 'f_ds_apelido=transjr&f_ds_senha=[FILTERED]',
                                  response_headers: { 'location' => 'index.php', 'set-cookie' => 'PHPSESSID=[FILTERED]; path=/' },
                                  response_content_type: 'text/html', response_body: nil, response_size: 0, duration_ms: 1_250,
                                  created_at: now - 3.hours)
    end
    let!(:home) do
      create(:admin_http_request, integration_type: 'atua', tenant:, atua_import: import, trace_id: login.trace_id,
                                  url: 'https://atua.example.test/adm/index.php', response_content_type: 'text/html',
                                  response_headers: { 'content-type' => 'text/html' }, response_body: '<html>Bem-vindo</html>',
                                  response_size: 22, duration_ms: 300, created_at: now - 3.hours + 1.second)
    end
    let!(:report) do
      create(:admin_http_request, integration_type: 'atua', tenant:, atua_import: import, http_method: 'POST',
                                  url: 'https://atua.example.test/adm/rel_cliente_detalhado.php', response_content_type: 'application/vnd.ms-excel',
                                  response_headers: { 'content-type' => 'application/vnd.ms-excel' }, response_body: nil,
                                  response_binary: true, response_size: 1_258_291, duration_ms: 8_400, created_at: now - 2.hours)
    end
    let!(:geocode) do
      create(:admin_http_request, url: 'https://api.tomtom.com/search/2/geocode/Betim.json?countrySet=BR&key=[FILTERED]',
                                  response_body: '{"results":[{"id":1}]}', created_at: now - 1.hour)
    end
    let!(:timeout) do
      create(:admin_http_request, url: 'https://api.tomtom.com/routing/1/calculateRoute/1,2:3,4/json?key=[FILTERED]',
                                  status_code: nil, status_message: nil, response_headers: {}, response_content_type: nil,
                                  response_body: nil, response_size: nil, duration_ms: 10_000, error_class: 'Net::ReadTimeout',
                                  error_message: 'Net::ReadTimeout with #<TCPSocket:(closed)>', created_at: now - 30.minutes)
    end

    before { sign_in_admin(admin_user) }

    scenario 'lists the requests from the newest with their status and duration' do
      within('#sidebar') { click_on 'Requisições HTTP' }

      expect(page).to have_current_path(admin_http_requests_path)
      expect(Admin::HttpRequest.count).to eq(5)
      expect(html_table_to_rows(table: find('table'))).to eq(
        [
          ['URL', 'Status HTTP', 'Data', 'Integração', 'Empresa', 'Duração', 'Ações'],
          ['GET api.tomtom.com/routing/1/calculateRoute/1,2:3,4/json 14 de outubro, 11:30', 'Sem resposta', '14 de outubro, 11:30', 'TomTom', '-', '10.000 ms',
           ''],
          ['GET api.tomtom.com/search/2/geocode/Betim.json 14 de outubro, 11:00', '200 OK', '14 de outubro, 11:00', 'TomTom', '-', '120 ms', ''],
          ['POST atua.example.test/adm/rel_cliente_detalhado.php 14 de outubro, 10:00', '200 OK', '14 de outubro, 10:00', 'Atua', 'TransJR',
           '8.400 ms', ''],
          ['GET atua.example.test/adm/index.php 14 de outubro, 09:00', '200 OK', '14 de outubro, 09:00', 'Atua', 'TransJR', '300 ms', ''],
          ['POST atua.example.test/adm/login.php 14 de outubro, 09:00', '302 Found', '14 de outubro, 09:00', 'Atua', 'TransJR', '1.250 ms', ''],
        ],
      )
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 5', 'Com sucesso 4', 'Com falha 1'])
      expect(page).to have_text('5 registros')
    end

    scenario 'filters the requests by integration, status, tenant, URL and period' do
      visit admin_http_requests_path
      select 'Atua', from: 'Integração'
      select 'Sucesso (2xx)', from: 'Status HTTP'
      select 'TransJR', from: 'Empresa'
      fill_in 'URL', with: 'rel_cliente'
      fill_in 'Data a partir de', with: '2026-10-14'
      fill_in 'Data até', with: '2026-10-14'
      click_on 'Aplicar Filtros'

      expect(html_table_to_rows(table: find('table')).drop(1).map(&:first)).to eq(
        ['POST atua.example.test/adm/rel_cliente_detalhado.php 14 de outubro, 10:00'],
      )
      expect(all('.counter-card').map { |card| card.text.squish }).to eq(['Total 1', 'Com sucesso 1', 'Com falha 0'])
    end

    scenario 'shows only the requests without a response' do
      visit admin_http_requests_path(status: 'failed')

      expect(html_table_to_rows(table: find('table')).drop(1).map(&:second)).to eq(['Sem resposta'])
    end

    scenario 'shows what was sent and what came back in a form post' do
      visit admin_http_requests_path
      within("#admin_http_request_#{login.id}") { click_on 'Visualizar' }

      expect(page).to have_current_path(admin_http_request_path(login))
      expect(page).to have_css('.page-title', text: 'POST atua.example.test/adm/login.php')
      expect(dl_to_hash('#http_request_data')).to eq(
        'Status HTTP' => '302 Found',
        'Integração' => 'Atua',
        'Método' => 'POST',
        'URL' => 'https://atua.example.test/adm/login.php',
        'Data' => '14 de outubro de 2026, 09:00',
        'Duração' => '1.250 ms',
        'Tentativa' => '1',
        'Empresa' => 'TransJR',
        'Importação' => 'Clientes',
        'Erro' => '-',
      )

      within('#http_request_sent') do
        expect(html_table_to_rows(table: find('#http_request_sent_headers table'))).to eq(
          [['content-type', 'application/x-www-form-urlencoded'], ['cookie', 'PHPSESSID=[FILTERED]']],
        )
        expect(html_table_to_rows(table: find('#http_request_sent_params table'))).to eq([%w[f_ds_apelido transjr], ['f_ds_senha', '[FILTERED]']])
        expect(find('#http_request_sent_body pre').text).to eq('f_ds_apelido=transjr&f_ds_senha=[FILTERED]')
      end

      within('#http_request_received') do
        expect(html_table_to_rows(table: find('#http_request_received_headers table'))).to eq(
          [%w[location index.php], ['set-cookie', 'PHPSESSID=[FILTERED]; path=/']],
        )
        expect(page).to have_no_css('#http_request_received_params')
        expect(find_by_id('http_request_received_body')).to have_text('Body vazio.')
      end

      within('#http_request_chain') do
        expect(page).to have_css('.active', text: 'POST /adm/login.php 302 Found')
        click_on 'GET /adm/index.php 200 OK'
      end

      expect(page).to have_current_path(admin_http_request_path(home))
      expect(find('#http_request_received_body pre').text).to eq('<html>Bem-vindo</html>')
    end

    scenario 'shows the indented JSON body and the query string of a request' do
      visit admin_http_request_path(geocode)

      expect(page).to have_css('#http_request_data')
      expect(page).to have_no_css('#http_request_chain')
      expect(html_table_to_rows(table: find('#http_request_sent_params table'))).to eq([%w[countrySet BR], ['key', '[FILTERED]']])
      expect(find_by_id('http_request_sent_body')).to have_text('Body vazio.')
      expect(find('#http_request_received_body pre').native.text).to eq(JSON.pretty_generate('results' => [{ 'id' => 1 }]))
    end

    scenario 'describes a binary spreadsheet instead of showing it' do
      visit admin_http_request_path(report)

      expect(find_by_id('http_request_received_body')).to have_text('Arquivo binário (application/vnd.ms-excel, 1,2 MB). O conteúdo não é exibido.')
    end

    scenario 'shows the error of a request without a response' do
      visit admin_http_request_path(timeout)

      expect(dl_to_hash('#http_request_data')).to include(
        'Status HTTP' => 'Sem resposta', 'Erro' => 'Net::ReadTimeout: Net::ReadTimeout with #<TCPSocket:(closed)>',
      )
      expect(find_by_id('http_request_received_body')).to have_text('A requisição não recebeu resposta.')
    end

    scenario 'lists the requests of an import from its link' do
      visit admin_http_request_path(login)
      click_on 'Clientes'

      expect(page).to have_current_path(admin_http_requests_path(atua_import_id: import.id))
      expect(html_table_to_rows(table: find('table')).drop(1).size).to eq(3)
    end

    scenario 'answers not found for an unknown request' do
      visit admin_http_request_path(id: 0)

      expect(page.status_code).to eq(404)
    end
  end

  context 'with a request opened on a phone', :js do
    let!(:http_request) do
      create(:admin_http_request, url: 'https://api.tomtom.com/search/2/geocode/Rua%20das%20Flores%2010%2C%20Betim%2C%20MG.json?countrySet=BR&key=[FILTERED]',
                                  response_body: { results: [{ id: 1, address: 'Rua das Flores, 10, Betim' * 10 }] }.to_json)
    end

    before { sign_in_admin(admin_user) }

    scenario 'keeps the essential columns and switches between headers and body without scrolling sideways' do
      visit admin_http_requests_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'STATUS HTTP')
      expect(page).to have_no_css('th', text: 'INTEGRAÇÃO')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      click_on 'Visualizar'

      within('#http_request_received') do
        expect(page).to have_css('#http_request_received_headers', visible: :visible)
        click_button 'Body'
        expect(page).to have_css('#http_request_received_body pre', visible: :visible, text: 'Rua das Flores')
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
