require 'rails_helper'

RSpec.describe Admin::HttpRequest do
  describe 'validations' do
    it 'requires the trace, method and URL' do
      http_request = described_class.new(integration_type: 'atua')

      expect(http_request).not_to be_valid
      expect(http_request.errors.attribute_names).to contain_exactly(:trace_id, :http_method, :url)
    end

    it 'rejects an unknown integration' do
      http_request = build(:admin_http_request, integration_type: 'other')

      expect(http_request).not_to be_valid
      expect(http_request.errors.attribute_names).to eq([:integration_type])
    end
  end

  describe 'scopes' do
    context 'with requests of every status' do
      let!(:ok) { create(:admin_http_request, status_code: 200, url: 'https://atua.example.test/adm/login.php') }
      let!(:redirect) { create(:admin_http_request, status_code: 302) }
      let!(:not_found) { create(:admin_http_request, status_code: 404) }
      let!(:server_error) { create(:admin_http_request, status_code: 503) }
      let!(:timeout) { create(:admin_http_request, status_code: nil, status_message: nil, error_class: 'Net::ReadTimeout') }

      it 'splits the requests that succeeded from the ones that failed' do
        expect(described_class.succeeded).to contain_exactly(ok, redirect)
        expect(described_class.failed).to contain_exactly(not_found, server_error, timeout)
      end

      it 'filters by status group' do
        expect(described_class.by_status_group('success')).to eq([ok])
        expect(described_class.by_status_group('redirection')).to eq([redirect])
        expect(described_class.by_status_group('client_error')).to eq([not_found])
        expect(described_class.by_status_group('server_error')).to eq([server_error])
        expect(described_class.by_status_group('failed')).to eq([timeout])
        expect(described_class.by_status_group('unknown').count).to eq(5)
      end

      it 'searches the URL ignoring case and LIKE wildcards' do
        expect(described_class.by_url('LOGIN.php')).to eq([ok])
        expect(described_class.by_url('%')).to be_empty
      end
    end

    context 'with requests made on different days' do
      let!(:old) { create(:admin_http_request, created_at: 31.days.ago) }
      let!(:yesterday) { create(:admin_http_request, created_at: 1.day.ago) }
      let!(:today) { create(:admin_http_request) }

      it 'finds the requests older than the retention' do
        expect(described_class.expired).to eq([old])
      end

      it 'filters by period and ignores invalid dates' do
        expect(described_class.by_period_start(Date.current.iso8601)).to eq([today])
        expect(described_class.by_period_end(1.day.ago.to_date.iso8601)).to contain_exactly(old, yesterday)
        expect(described_class.by_period_start('invalid').count).to eq(3)
      end
    end
  end

  describe '#chain' do
    let(:trace_id) { SecureRandom.uuid }
    let!(:first) { create(:admin_http_request, trace_id:, status_code: 302) }
    let!(:last) { create(:admin_http_request, trace_id:, status_code: 200) }

    before { create(:admin_http_request) }

    it 'returns every hop of the same trace in order' do
      expect(last.chain).to eq([first, last])
    end
  end

  describe '#query_params' do
    it 'decodes the query string of the URL' do
      http_request = build(:admin_http_request, url: 'https://api.tomtom.com/geocode.json?countrySet=BR&limit=5&key=[FILTERED]')

      expect(http_request.query_params).to eq([%w[countrySet BR], %w[limit 5], ['key', '[FILTERED]']])
    end

    it 'returns nothing when there is no query string' do
      expect(build(:admin_http_request, url: 'https://atua.example.test/adm/login.php').query_params).to eq([])
    end
  end

  describe '#request_form_params' do
    it 'decodes a form body' do
      http_request = build(:admin_http_request, request_headers: { 'content-type' => 'application/x-www-form-urlencoded' },
                                                request_body: 'f_ds_apelido=transjr&f_ds_senha=[FILTERED]')

      expect(http_request.request_form_params).to eq([%w[f_ds_apelido transjr], ['f_ds_senha', '[FILTERED]']])
    end

    it 'ignores a body that is not a form' do
      http_request = build(:admin_http_request, request_headers: { 'content-type' => 'application/json' }, request_body: '{"a":1}')

      expect(http_request.request_form_params).to eq([])
    end
  end

  describe '#formatted_response_body' do
    it 'indents a JSON body' do
      http_request = build(:admin_http_request, response_body: '{"results":[{"id":1}]}')

      expect(http_request.formatted_response_body).to eq(JSON.pretty_generate('results' => [{ 'id' => 1 }]))
    end

    it 'keeps an invalid JSON body as it came' do
      expect(build(:admin_http_request, response_body: '{invalid').formatted_response_body).to eq('{invalid')
    end

    it 'keeps an HTML body as it came' do
      http_request = build(:admin_http_request, response_content_type: 'text/html', response_body: '<html>Bem-vindo</html>')

      expect(http_request.formatted_response_body).to eq('<html>Bem-vindo</html>')
    end
  end
end
