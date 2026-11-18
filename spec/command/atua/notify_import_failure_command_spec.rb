require 'rails_helper'

RSpec.describe Atua::NotifyImportFailureCommand do
  let!(:tenant) { create(:tenant, trade_name: 'TransJR') }
  let(:error) do
    original = Atua::DownloadError.new('HTTP 502', status: 502).tap { |raised| raised.set_backtrace(['lib/atua/client.rb:240']) }

    begin
      raise original
    rescue Atua::DownloadError
      begin
        raise Atua::RetryableError, original.message
      rescue Atua::RetryableError => e
        e
      end
    end
  end

  before { allow(Discord::NotifyErrorCommand).to receive(:call) }

  context 'when Discord is enabled' do
    before { allow(Discord).to receive(:enabled?).and_return(true) }

    it 'notifies Discord with the failed report, its period and the original error' do
      failure = described_class.call(tenant.id, 'manifests', Date.new(2026, 10, 1), Date.new(2026, 10, 13), error:, attempts: 3)

      expect(failure).to be_a(Atua::ImportFailedError)
      expect(failure.message).to eq(
        'A importação de Manifestos da TransJR (01/10/2026 a 13/10/2026) falhou 3 vezes seguidas ' \
        'e não será tentada de novo automaticamente: HTTP 502',
      )
      expect(failure.backtrace).to eq(['lib/atua/client.rb:240'])
      expect(Discord::NotifyErrorCommand).to have_received(:call)
        .with(failure, handled: false, context: { tenant_id: tenant.id }, source: 'atua.import_report')
    end

    it 'describes a registry imported without period' do
      failure = described_class.call(tenant.id, 'customers', error:, attempts: 3)

      expect(failure.message).to include('(sem período)')
      expect(Discord::NotifyErrorCommand).to have_received(:call).once
    end

    it 'notifies every failure without throttling' do
      2.times { described_class.call(tenant.id, 'manifests', error:, attempts: 3) }

      expect(Discord::NotifyErrorCommand).to have_received(:call).twice
    end
  end

  context 'when Discord is disabled' do
    before { allow(Discord).to receive(:enabled?).and_return(false) }

    it 'returns the failure without notifying Discord' do
      expect(described_class.call(tenant.id, 'manifests', error:, attempts: 3)).to be_a(Atua::ImportFailedError)
      expect(Discord::NotifyErrorCommand).not_to have_received(:call)
    end
  end
end
