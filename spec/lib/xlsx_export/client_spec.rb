require 'rails_helper'

RSpec.describe XlsxExport::Client do
  let(:client) { described_class.new(url: 'http://xlsx.test:4000', token: 'segredo') }
  let(:sheets) { [{ name: 'Veículos', columns: [{ header: 'Placa', type: :string }], rows: [['EXU0F72']] }] }
  let(:endpoint) { 'http://xlsx.test:4000/v1/workbooks' }

  describe '#workbook' do
    it 'posts the sheets with the token and returns the binary workbook' do
      stub_request(:post, endpoint).with(body: { sheets: }.to_json, headers: { 'Authorization' => 'Bearer segredo', 'Content-Type' => 'application/json' })
        .to_return(status: 200, body: "PK\x03\x04\xFF".b)

      workbook = client.workbook(sheets)

      expect(workbook).to eq("PK\x03\x04\xFF".b)
      expect(workbook.encoding).to eq(Encoding::BINARY)
    end

    it 'does not send the authorization header without a token' do
      stub_request(:post, endpoint).to_return(status: 200, body: 'PK')

      described_class.new(url: 'http://xlsx.test:4000', token: nil).workbook(sheets)

      expect(a_request(:post, endpoint).with { |request| !request.headers.key?('Authorization') }).to have_been_made
    end

    it 'raises the message of the service when it refuses the sheets' do
      stub_request(:post, endpoint).to_return(status: 422, body: { error: 'sheet "Veículos" must not export the "ID" column' }.to_json)

      expect { client.workbook(sheets) }
        .to raise_error(XlsxExport::RequestError, 'O serviço de planilhas respondeu HTTP 422: sheet "Veículos" must not export the "ID" column')
    end

    it 'raises the status when the token is refused' do
      stub_request(:post, endpoint).to_return(status: 401, body: { error: 'missing or invalid bearer token' }.to_json)

      expect { client.workbook(sheets) }.to raise_error(XlsxExport::RequestError, 'O serviço de planilhas respondeu HTTP 401: missing or invalid bearer token')
    end

    it 'raises a request error when the service is down' do
      stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED)

      expect { client.workbook(sheets) }.to raise_error(XlsxExport::RequestError, /\AO serviço de planilhas não respondeu: .*Connection refused/)
    end

    it 'raises a request error when the service takes too long' do
      stub_request(:post, endpoint).to_timeout

      expect { client.workbook(sheets) }.to raise_error(XlsxExport::RequestError, /\AO serviço de planilhas não respondeu/)
    end
  end

  describe '#inspect' do
    it 'hides the token' do
      expect(client.inspect).to eq('#<XlsxExport::Client url=http://xlsx.test:4000 token=[FILTERED]>')
    end
  end
end
