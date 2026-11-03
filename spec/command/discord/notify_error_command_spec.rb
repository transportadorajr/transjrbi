require 'rails_helper'

RSpec.describe Discord::NotifyErrorCommand do
  let(:webhook_url) { 'https://discord.com/api/webhooks/123/test-token' }
  let(:client) { Discord::Client.new(webhook_url:) }
  let(:error) do
    RuntimeError.new('Falha ao importar o relatório').tap do |raised|
      raised.set_backtrace(["#{Rails.root}/app/command/atua/example_command.rb:10:in 'call'"])
    end
  end

  before { stub_request(:post, webhook_url).to_return(status: 204) }

  it 'sends the error with its context to the Discord webhook' do
    travel_to Time.zone.local(2026, 11, 3, 10, 30) do
      described_class.call(error, handled: false, context: { tenant_id: 7, user_id: 42 }, source: 'application.action_dispatch', client:)
    end

    expect(WebMock).to(have_requested(:post, webhook_url).with do |request|
      expect(JSON.parse(request.body, symbolize_names: true)).to eq(
        username: 'JR BI - Erros',
        allowed_mentions: { parse: [] },
        embeds: [
          {
            title: 'RuntimeError',
            description: 'Falha ao importar o relatório',
            color: 0xDC3545,
            timestamp: '2026-11-03T10:30:00-03:00',
            fields: [
              { name: 'Ambiente', value: 'test', inline: true },
              { name: 'Origem', value: 'application.action_dispatch', inline: true },
              { name: 'Tipo', value: 'Não tratado', inline: true },
              { name: 'Tenant', value: '7', inline: true },
              { name: 'Usuário', value: '42', inline: true },
              { name: 'Backtrace', value: "```\napp/command/atua/example_command.rb:10:in 'call'\n```" },
            ],
          },
        ],
      )
    end)
  end

  it 'marks a handled error without a known source' do
    described_class.call(error, handled: true, client:)

    expect(WebMock).to(have_requested(:post, webhook_url).with do |request|
      fields = JSON.parse(request.body, symbolize_names: true).dig(:embeds, 0, :fields)

      expect(fields).to include({ name: 'Origem', value: 'desconhecida', inline: true }, { name: 'Tipo', value: 'Tratado', inline: true })
    end)
  end

  it 'does not raise when Discord is unavailable' do
    stub_request(:post, webhook_url).to_return(status: 500)

    expect(described_class.call(error, handled: false, client:)).to be_nil
  end
end
