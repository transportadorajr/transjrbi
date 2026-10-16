require 'rails_helper'

RSpec.describe Admin::HttpRequests::RecordCommand do
  let(:uri) { URI('https://atua.example.test/adm/login.php?f_popup=true') }

  def perform(http_request, **)
    described_class.call(:atua, http_request, **) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(http_request) }
    end
  end

  def post_form(form, headers = {})
    Net::HTTP::Post.new(uri).tap do |request|
      headers.each { |name, value| request[name] = value }
      request.set_form_data(form)
    end
  end

  context 'with a successful form post' do
    before do
      stub_request(:post, uri.to_s).to_return(
        status: [200, 'OK'], body: '<html>Bem-vindo, transjr</html>',
        headers: { 'Content-Type' => 'text/html; charset=UTF-8', 'Set-Cookie' => ['PHPSESSID=abc123; path=/', 'lang=pt; Max-Age=3600'] }
      )
    end

    it 'returns the response and records what was sent and what came back' do
      http_request = post_form({ 'f_ds_apelido' => 'transjr', 'f_ds_senha' => 'p@ss word' }, 'Cookie' => 'PHPSESSID=abc123', 'Referer' => uri.to_s)

      response = nil
      expect { response = perform(http_request, trace_id: 'f3c4c2a6-4d55-4a63-9b3c-1b4f0f6b1d2e', attempt: 2, secrets: ['p@ss word']) }
        .to change(Admin::HttpRequest, :count).by(1)

      expect(response.code).to eq('200')
      record = Admin::HttpRequest.last
      expect(record).to have_attributes(
        integration_type: 'atua', trace_id: 'f3c4c2a6-4d55-4a63-9b3c-1b4f0f6b1d2e', attempt: 2, http_method: 'POST',
        url: uri.to_s, request_body: 'f_ds_apelido=transjr&f_ds_senha=[FILTERED]', status_code: 200, status_message: 'OK',
        response_content_type: 'text/html; charset=UTF-8', response_body: '<html>Bem-vindo, transjr</html>', response_size: 31,
        response_binary: false, response_truncated: false, error_class: nil
      )
      expect(record.duration_ms).to be >= 0
      expect(record.request_headers).to include(
        'cookie' => 'PHPSESSID=[FILTERED]', 'referer' => uri.to_s, 'content-type' => 'application/x-www-form-urlencoded',
      )
      expect(record.response_headers).to include(
        'content-type' => 'text/html; charset=UTF-8', 'set-cookie' => "PHPSESSID=[FILTERED]; path=/\nlang=[FILTERED]; Max-Age=3600",
      )
    end

    it 'generates a trace for a request without one' do
      perform(post_form('a' => '1'))

      expect(Admin::HttpRequest.last.trace_id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it 'links the request to the import being downloaded' do
      import = create(:atua_import)

      Current.set(atua_import: import) { perform(post_form('a' => '1')) }

      expect(Admin::HttpRequest.last).to have_attributes(atua_import_id: import.id, tenant_id: import.tenant_id)
    end
  end

  context 'with a secret in the query string and in the response' do
    let(:uri) { URI('https://api.tomtom.com/search/2/geocode/Betim.json?countrySet=BR&key=api-key-123') }

    before { stub_request(:get, uri.to_s).to_return(status: 403, body: '{"error":"invalid key api-key-123"}', headers: { 'Content-Type' => 'application/json' }) }

    it 'filters the secret everywhere' do
      perform(Net::HTTP::Get.new(uri), secrets: ['api-key-123'])

      expect(Admin::HttpRequest.last).to have_attributes(
        url: 'https://api.tomtom.com/search/2/geocode/Betim.json?countrySet=BR&key=[FILTERED]', status_code: 403,
        response_body: '{"error":"invalid key [FILTERED]"}'
      )
    end
  end

  context 'with a binary spreadsheet in the response' do
    before do
      stub_request(:get, uri.to_s).to_return(status: 200, body: "\xD0\xCF\x11\xE0\x00\x01".b, headers: { 'Content-Type' => 'application/vnd.ms-excel' })
    end

    it 'keeps only the type and size of the content' do
      perform(Net::HTTP::Get.new(uri))

      expect(Admin::HttpRequest.last).to have_attributes(
        response_binary: true, response_body: nil, response_size: 6, response_content_type: 'application/vnd.ms-excel',
      )
    end
  end

  context 'with a response bigger than 1 MB' do
    before { stub_request(:get, uri.to_s).to_return(status: 200, body: 'a' * (1.megabyte + 10), headers: { 'Content-Type' => 'text/html' }) }

    it 'keeps the first megabyte and flags the body as truncated' do
      perform(Net::HTTP::Get.new(uri))

      record = Admin::HttpRequest.last
      expect(record.response_body.bytesize).to eq(1.megabyte)
      expect(record).to have_attributes(response_truncated: true, response_size: 1.megabyte + 10)
    end
  end

  context 'with a page encoded in ISO-8859-1' do
    before { stub_request(:get, uri.to_s).to_return(status: 200, body: 'Relatório'.encode(Encoding::ISO_8859_1), headers: { 'Content-Type' => 'text/html' }) }

    it 'stores the body converted to UTF-8' do
      perform(Net::HTTP::Get.new(uri))

      expect(Admin::HttpRequest.last.response_body).to eq('Relatório')
    end
  end

  context 'when the request does not get a response' do
    before { stub_request(:get, uri.to_s).to_timeout }

    it 'records the error and raises it again' do
      expect { perform(Net::HTTP::Get.new(uri)) }.to raise_error(Net::OpenTimeout)

      expect(Admin::HttpRequest.last).to have_attributes(
        status_code: nil, response_body: nil, error_class: 'Net::OpenTimeout', error_message: 'execution expired',
      )
    end
  end

  context 'when the request cannot be recorded' do
    before do
      stub_request(:get, uri.to_s).to_return(status: 200, body: 'ok')
      allow(Admin::HttpRequest).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'database is down')
      allow(Rails.logger).to receive(:error)
    end

    it 'still returns the response and logs the failure' do
      expect(perform(Net::HTTP::Get.new(uri)).body).to eq('ok')

      expect(Rails.logger).to have_received(:error).with(%r{\[HttpRequests\] could not record GET /adm/login.php})
    end
  end
end
