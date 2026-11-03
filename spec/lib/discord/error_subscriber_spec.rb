require 'rails_helper'

RSpec.describe Discord::ErrorSubscriber do
  let(:subscriber) { described_class.new }
  let(:error) { RuntimeError.new('Falha inesperada').tap { |raised| raised.set_backtrace(['app/models/sale.rb:1']) } }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(Discord::NotifyErrorCommand).to receive(:call)
  end

  it 'notifies Discord about a server error' do
    subscriber.report(error, handled: false, severity: :error, context: { user_id: 1 }, source: 'application.action_dispatch')

    expect(Discord::NotifyErrorCommand).to have_received(:call)
      .with(error, handled: false, context: { user_id: 1 }, source: 'application.action_dispatch')
  end

  it 'notifies the same error only once within the throttle period' do
    2.times { subscriber.report(error, handled: false, severity: :error, context: {}) }

    expect(Discord::NotifyErrorCommand).to have_received(:call).once
  end

  it 'notifies the same error again after the throttle period' do
    subscriber.report(error, handled: false, severity: :error, context: {})

    travel 61.minutes do
      subscriber.report(error, handled: false, severity: :error, context: {})
    end

    expect(Discord::NotifyErrorCommand).to have_received(:call).twice
  end

  it 'ignores warnings' do
    subscriber.report(error, handled: true, severity: :warning, context: {})

    expect(Discord::NotifyErrorCommand).not_to have_received(:call)
  end

  it 'ignores errors that become client error responses' do
    subscriber.report(ActiveRecord::RecordNotFound.new, handled: false, severity: :error, context: {})

    expect(Discord::NotifyErrorCommand).not_to have_received(:call)
  end

  it 'ignores failures of the Discord notification itself' do
    subscriber.report(Discord::Error.new('O Discord respondeu HTTP 500.'), handled: false, severity: :error, context: {})

    expect(Discord::NotifyErrorCommand).not_to have_received(:call)
  end
end
