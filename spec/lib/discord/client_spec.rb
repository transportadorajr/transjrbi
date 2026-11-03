require 'rails_helper'

RSpec.describe Discord::Client do
  let(:webhook_url) { 'https://discord.com/api/webhooks/123/test-token' }
  let(:client) { described_class.new(webhook_url:) }
  let(:payload) { { content: 'Erro em produção' } }

  describe '#execute_webhook' do
    it 'posts the payload as JSON to the webhook' do
      stub_request(:post, webhook_url).to_return(status: 204)

      client.execute_webhook(payload)

      expect(WebMock).to have_requested(:post, webhook_url)
        .with(body: { content: 'Erro em produção' }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'raises an error when Discord rejects the payload' do
      stub_request(:post, webhook_url).to_return(status: 400)

      expect { client.execute_webhook(payload) }.to raise_error(Discord::Error, 'O Discord respondeu HTTP 400.')
    end

    it 'raises an error when the request times out' do
      stub_request(:post, webhook_url).to_timeout

      expect { client.execute_webhook(payload) }.to raise_error(Discord::Error, /A requisição para o webhook do Discord falhou/)
    end
  end

  describe '#inspect' do
    it 'does not expose the webhook token' do
      expect(client.inspect).to eq('#<Discord::Client webhook_url=[FILTERED]>')
    end
  end
end
