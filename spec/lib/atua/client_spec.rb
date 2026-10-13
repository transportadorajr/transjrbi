require 'rails_helper'

RSpec.describe Atua::Client do
  let(:base_url) { 'https://atua.example.test/adm' }
  let(:password) { 'secret-password' }
  let(:configuration) { Atua::Configuration.new(base_url:, username: 'transjr', password:) }
  let(:client) { described_class.new(configuration) }
  let(:xls) { file_fixture('atua/customers.xls').binread }
  let(:login_form) do
    <<~HTML
      <html><body><form action="login.php" method="post">
        <input type="hidden" name="f_form_login_submitted" value="1">
        <input type="hidden" name="f_origem" value="login.php">
        <input type="hidden" name="f_id_hash_aplicativo" value="">
        <input type="text" name="f_ds_apelido" value="">
        <input type="password" name="f_ds_senha" value="">
        <input type="hidden" name="f_popup" value="true">
        <input type="hidden" name="f_iframe" value="">
        <input type="submit" name="submete051031" value="Acessar">
      </form></body></html>
    HTML
  end
  let(:xls_response) { { status: 200, body: xls, headers: { 'Content-Type' => 'application/vnd.ms-excel', 'Content-Disposition' => 'attachment; filename="9430_rel.xls"' } } }
  let(:posted) { [] }

  before { allow(client).to receive(:pause) }

  def stub_login(status: 200, body: '<html>Bem-vindo</html>')
    stub_request(:get, "#{base_url}/login.php?f_popup=true")
      .to_return(status: 200, body: login_form, headers: { 'Set-Cookie' => 'PHPSESSID=abc123; path=/' })
    stub_request(:post, "#{base_url}/login.php").to_return(status:, body:)
  end

  def stub_form(endpoint, body: '<form><input type="submit" name="submete777777" value="Gerar"></form>')
    stub_request(:get, "#{base_url}/#{endpoint}").to_return(status: 200, body:)
  end

  def stub_report(endpoint, *responses)
    stub_request(:post, "#{base_url}/#{endpoint}")
      .with { |request| posted << URI.decode_www_form(request.body) }
      .to_return(*(responses.presence || [xls_response]))
  end

  def report_keys(type)
    definition = YAML.load_file(Rails.root.join("config/atua/reports/#{type}.yml"))
    [definition['submitted_field'], *definition['params'].keys]
  end

  describe '#login' do
    context 'when the credentials are accepted' do
      before { stub_login }

      it 'posts every field of the login form with the filled credentials and browser headers' do
        client.login

        expect(client).to be_logged_in
        expect(
          a_request(:post, "#{base_url}/login.php")
            .with(
              body: {
                'f_form_login_submitted' => '1',
                'f_origem' => 'login.php',
                'f_id_hash_aplicativo' => '',
                'f_ds_apelido' => 'transjr',
                'f_ds_senha' => password,
                'f_popup' => 'true',
                'f_iframe' => '',
                'submete051031' => 'Acessar',
              },
              headers: {
                'Origin' => 'https://atua.example.test',
                'Referer' => "#{base_url}/login.php?f_popup=true",
                'Cookie' => 'PHPSESSID=abc123',
                'User-Agent' => described_class::USER_AGENT,
              },
            ),
        ).to have_been_made.once
      end

      it 'fills the application hash from the configuration when present' do
        configuration = Atua::Configuration.new(base_url:, username: 'transjr', password:, device_hash: 'deadbeefhash')
        client = described_class.new(configuration)
        allow(client).to receive(:pause)

        client.login

        expect(a_request(:post, "#{base_url}/login.php").with(body: hash_including('f_id_hash_aplicativo' => 'deadbeefhash'))).to have_been_made.once
      end

      it 'sends an empty application hash when none is configured' do
        client.login

        expect(a_request(:post, "#{base_url}/login.php").with(body: hash_including('f_id_hash_aplicativo' => ''))).to have_been_made.once
      end

      it 'reads the dynamic submit button name from the login form' do
        stub_request(:get, "#{base_url}/login.php?f_popup=true")
          .to_return(status: 200, body: login_form.sub('submete051031', 'submete999999'), headers: { 'Set-Cookie' => 'PHPSESSID=abc123; path=/' })

        client.login

        expect(a_request(:post, "#{base_url}/login.php").with(body: hash_including('submete999999' => 'Acessar'))).to have_been_made.once
      end

      it 'does not log in again when the session is already open' do
        client.login
        client.login

        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end
    end

    context 'when the credentials are refused' do
      before { stub_login(body: %(<html><body><p>Senha #{password} inválida</p><input name="f_ds_senha"></body></html>)) }

      it 'raises an authentication error once, without retrying nor exposing the password' do
        expect { client.login }.to raise_error(Atua::AuthenticationError) { |error|
          expect(error.message).not_to include(password)
          expect(error.body_excerpt).to include('[FILTERED]')
          expect(error.body_excerpt).not_to include(password)
        }

        expect(client).not_to be_logged_in
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end
    end

    context 'when the login answers with a client error status' do
      before { stub_login(status: 403, body: 'Forbidden') }

      it 'raises an authentication error with the status' do
        expect { client.login }.to raise_error(Atua::AuthenticationError) { |error| expect(error.status).to eq(403) }
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end
    end

    context 'when the login post answers with a server error' do
      before { stub_login(status: 520, body: 'Web server is returning an unknown error') }

      it 'raises a session error without repeating the login' do
        expect { client.login }.to raise_error(Atua::SessionError, /HTTP 520/) { |error| expect(error.status).to eq(520) }
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end
    end
  end

  describe '#download' do
    context 'with a report that has a form button' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php')
        stub_report('rel_cliente_detalhado.php')
      end

      it 'returns the raw content, content type and suggested file name' do
        downloads = client.download(:customers)

        expect(downloads.size).to eq(1)
        expect(downloads.first.content).to eq(xls)
        expect(downloads.first.content_type).to eq('application/vnd.ms-excel')
        expect(downloads.first.filename).to eq('9430_rel.xls')
        expect(downloads.first.report_type).to eq(:customers)
      end

      it 'submits the button name read from the form' do
        client.download(:customers)

        expect(posted.first.last).to eq(%w[submete777777 Gerar])
        expect(posted.first.map(&:first)).not_to include('submete101053')
      end

      it 'sends the session cookie, origin and referer to the report' do
        client.download(:customers)

        expect(
          a_request(:post, "#{base_url}/rel_cliente_detalhado.php")
            .with(headers: { 'Cookie' => 'PHPSESSID=abc123', 'Origin' => 'https://atua.example.test', 'Referer' => "#{base_url}/rel_cliente_detalhado.php" }),
        ).to have_been_made.once
      end

      it 'waits 2 seconds between requests' do
        client.download(:customers)

        expect(client).to have_received(:pause).with(2).exactly(3).times
      end

      it 'reuses the session for the next reports' do
        client.download(:customers)
        client.download(:customers)

        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end

      it 'calls the block with each download' do
        yielded = []
        client.download(:customers) { |download| yielded << download.report_type }

        expect(yielded).to eq([:customers])
      end
    end

    context 'when the form does not show the submit button' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php', body: '<form></form>')
        stub_report('rel_cliente_detalhado.php')
      end

      it 'falls back to the button name of the configuration' do
        client.download(:customers)

        expect(posted.first.last).to eq(%w[submete101053 Gerar])
      end
    end

    context 'when building the parameters of each report' do
      before do
        travel_to Time.zone.local(2026, 10, 13, 9, 0)
        stub_login
        %w[rel_manifesto_detalhado.php rel_caixa_detalhado.php rel_cliente_detalhado.php rel_veiculo_terceiro_detalhado.php].each { stub_form(it) }
        %w[rel_ctrc_detalhado.php rel_manifesto_detalhado.php rel_caixa_detalhado.php rel_cliente_detalhado.php rel_veiculo_terceiro_detalhado.php].each { stub_report(it) }
      end

      it 'posts transport documents straight to the report with the issue dates' do
        client.download(:transport_documents, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))
        params = posted.first.to_h

        expect(a_request(:get, "#{base_url}/rel_ctrc_detalhado.php")).not_to have_been_made
        expect(posted.first.map(&:first)).to eq(report_keys(:transport_documents))
        expect(params).to include(
          'f__submitted' => '1',
          'f_dt_emissao_inicio' => '01/10/2026',
          'f_dt_emissao_final' => '13/10/2026',
          'f_cd_pessoa_matriz_0' => '2',
          'f_id_cancelado_sistema' => '0',
          'f_id_formato' => '2',
          'f_id_permite_submit' => '1',
          'f_arr_nm_campos_dinamicos[cd_ctrc]' => '1',
          'f_dt_lancamento_inicio' => '',
        )
        expect(params.keys.grep(/\Asubmete/)).to be_empty
      end

      it 'defaults the period to the beginning of the current month through today when no dates are given' do
        client.download(:transport_documents)
        params = posted.first.to_h

        expect(params).to include('f_dt_emissao_inicio' => '01/10/2026', 'f_dt_emissao_final' => '13/10/2026')
      end

      it 'defaults only the start date to the beginning of the current month when just the end date is given' do
        client.download(:manifests, end_date: Date.new(2026, 10, 10))
        params = posted.first.to_h

        expect(params).to include('f_dt_lancamento_inicio' => '01/10/2026', 'f_dt_lancamento_termino' => '10/10/2026')
      end

      it 'posts manifests with the posting dates and the button' do
        client.download(:manifests, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))
        params = posted.first.to_h

        expect(posted.first.map(&:first)).to eq([*report_keys(:manifests), 'submete777777'])
        expect(params).to include(
          'f__submitted' => '1',
          'f_dt_lancamento_inicio' => '01/10/2026',
          'f_dt_lancamento_termino' => '13/10/2026',
          'f_cd_pessoa_matriz' => '2',
          'f_id_situacao' => '4',
          'f_dt_emissao_inicio' => '',
          'submete777777' => 'Gerar',
        )
      end

      it 'posts expenses with the posting dates and today as the billing base date' do
        client.download(:expenses, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))
        params = posted.first.to_h

        expect(posted.first.map(&:first)).to eq([*report_keys(:expenses), 'submete777777'])
        expect(params).to include(
          'f__submitted' => '1',
          'f_dt_lancamento_inicial' => '01/10/2026',
          'f_dt_lancamento_final' => '13/10/2026',
          'f_dt_base_id_cobranca' => '13/10/2026',
          'f_cd_pessoa_matriz' => '',
          'f_id_tipo_estoque' => '{0}',
          'f_id_listar' => 'Despesa',
          'f_id_ordenacao' => '2',
        )
      end

      it 'posts customers without period' do
        client.download(:customers)
        params = posted.first.to_h

        expect(posted.first.map(&:first)).to eq([*report_keys(:customers), 'submete777777'])
        expect(params).to include('f__submitted' => '1', 'f_dt_emissao_inicio' => '', 'f_dt_emissao_termino' => '', 'f_id_atividade' => '~*', 'f_id_tipo_cliente' => '0')
      end

      it 'posts vehicles with its own control field' do
        client.download(:vehicles)
        params = posted.first.to_h

        expect(posted.first.map(&:first)).to eq([*report_keys(:vehicles), 'submete777777'])
        expect(params).to include('f_form_submitted' => '1', 'f_id_situacao_cadastro' => '2', 'f_id_lista_motorista' => '1')
        expect(params).not_to have_key('f__submitted')
      end
    end

    context 'with invalid periods' do
      it 'refuses dates on reports without period' do
        expect { client.download(:vehicles, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 2)) }.to raise_error(ArgumentError)
      end

      it 'refuses a start date after the end date' do
        expect { client.download(:manifests, start_date: Date.new(2026, 10, 2), end_date: Date.new(2026, 10, 1)) }.to raise_error(ArgumentError)
      end

      it 'refuses an unknown report' do
        expect { client.download(:invoices) }.to raise_error(ArgumentError)
      end
    end

    context 'when the period is longer than 31 days' do
      before do
        stub_login
        stub_report('rel_ctrc_detalhado.php')
      end

      it 'splits the period in monthly slices' do
        downloads = client.download(:transport_documents, start_date: Date.new(2026, 8, 15), end_date: Date.new(2026, 10, 2))

        expect(downloads.map { [it.start_date, it.end_date] }).to eq(
          [
            [Date.new(2026, 8, 15), Date.new(2026, 8, 31)],
            [Date.new(2026, 9, 1), Date.new(2026, 9, 30)],
            [Date.new(2026, 10, 1), Date.new(2026, 10, 2)],
          ],
        )
        expect(posted.map { it.to_h.values_at('f_dt_emissao_inicio', 'f_dt_emissao_final') }).to eq(
          [%w[15/08/2026 31/08/2026], %w[01/09/2026 30/09/2026], %w[01/10/2026 02/10/2026]],
        )
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      end

      it 'keeps a period of exactly 31 days in a single request' do
        client.download(:transport_documents, start_date: Date.new(2026, 8, 15), end_date: Date.new(2026, 9, 14))

        expect(posted.size).to eq(1)
      end
    end

    context 'when the session expires' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php')
      end

      it 'logs in again once and repeats the download' do
        stub_report('rel_cliente_detalhado.php', { status: 200, body: login_form }, xls_response)

        downloads = client.download(:customers)

        expect(downloads.first.content).to eq(xls)
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.twice
        expect(posted.size).to eq(2)
      end

      it 'raises a session error when it expires again after the new login' do
        stub_report('rel_cliente_detalhado.php', { status: 200, body: login_form })

        expect { client.download(:customers) }.to raise_error(Atua::SessionError)
        expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.twice
      end
    end

    context 'when the server answers 520' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php')
      end

      it 'retries with increasing waits and returns the file' do
        stub_report('rel_cliente_detalhado.php', { status: 520, body: 'Cloudflare 520' }, { status: 520, body: 'Cloudflare 520' }, xls_response)

        downloads = client.download(:customers)

        expect(downloads.first.content).to eq(xls)
        expect(posted.size).to eq(3)
        expect(client).to have_received(:pause).with(5).ordered
        expect(client).to have_received(:pause).with(10).ordered
      end

      it 'gives up after 3 attempts' do
        stub_report('rel_cliente_detalhado.php', { status: 520, body: 'Cloudflare 520' })

        expect { client.download(:customers) }.to raise_error(Atua::DownloadError, /HTTP 520/) { |error| expect(error.status).to eq(520) }
        expect(posted.size).to eq(3)
      end

      it 'does not retry when the retries are disabled' do
        client = described_class.new(configuration, retries: false)
        allow(client).to receive(:pause)
        stub_report('rel_cliente_detalhado.php', { status: 520, body: 'Cloudflare 520' })

        expect { client.download(:customers) }.to raise_error(Atua::DownloadError, /HTTP 520/)
        expect(posted.size).to eq(1)
      end
    end

    context 'when the request times out' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php')
        stub_request(:post, "#{base_url}/rel_cliente_detalhado.php").to_timeout.then.to_return(xls_response)
      end

      it 'retries the request' do
        expect(client.download(:customers).first.content).to eq(xls)
        expect(a_request(:post, "#{base_url}/rel_cliente_detalhado.php")).to have_been_made.twice
      end
    end

    context 'when the report comes as HTML instead of Excel' do
      before do
        stub_login
        stub_form('rel_cliente_detalhado.php')
        stub_report('rel_cliente_detalhado.php', { status: 200, body: '<html><body>Nenhum registro encontrado</body></html>', headers: { 'Content-Type' => 'text/html' } })
      end

      it 'raises a download error with an excerpt of the body without retrying' do
        expect { client.download(:customers) }.to raise_error(Atua::DownloadError, /Nenhum registro encontrado/) { |error|
          expect(error.status).to eq(200)
          expect(error.headers).to eq('content-type' => 'text/html')
          expect(error.body_excerpt).to eq('<html><body>Nenhum registro encontrado</body></html>')
        }
        expect(posted.size).to eq(1)
      end
    end

    context 'when the response has no file name' do
      before do
        stub_login
        stub_report('rel_ctrc_detalhado.php', { status: 200, body: xls })
      end

      it 'suggests a name with the report and the period' do
        download = client.download(:transport_documents, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 1)).first

        expect(download.filename).to eq('transport_documents_20261001.xls')
      end
    end
  end

  describe 'device cookie' do
    let(:device_cookie) { 'c_ds_dispositivo_transjr_9430=token123' }
    let(:configuration) { Atua::Configuration.new(base_url:, username: 'transjr', password:, device_cookie:) }

    before { stub_login }

    it 'sends the seeded device cookie from the first request' do
      client.login

      expect(a_request(:get, "#{base_url}/login.php?f_popup=true").with(headers: { 'Cookie' => device_cookie })).to have_been_made.once
    end

    it 'keeps the device cookie available alongside the session cookie' do
      client.login

      expect(client.device_cookie).to eq(device_cookie)
    end

    it 'updates the device cookie when the server sends a new one' do
      stub_request(:get, "#{base_url}/login.php?f_popup=true")
        .to_return(status: 200, body: login_form, headers: { 'Set-Cookie' => ['PHPSESSID=abc123; path=/', 'c_ds_dispositivo_transjr_9430=renewed; path=/'] })

      client.login

      expect(client.device_cookie).to eq('c_ds_dispositivo_transjr_9430=renewed')
    end

    context 'without a seeded device cookie' do
      let(:configuration) { Atua::Configuration.new(base_url:, username: 'transjr', password:) }

      it 'has no device cookie' do
        client.login

        expect(client.device_cookie).to be_nil
      end
    end
  end

  describe '#inspect' do
    it 'does not show the password' do
      expect(client.inspect).not_to include(password)
    end
  end
end
