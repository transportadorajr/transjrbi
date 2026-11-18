require 'rails_helper'

RSpec.describe Discord do
  describe '.enabled?' do
    before { allow(described_class).to receive(:error_webhook_url).and_return('https://discord.com/api/webhooks/1/token') }

    it 'is enabled in production with a webhook configured' do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(described_class).to be_enabled
    end

    it 'is disabled outside production' do
      expect(described_class).not_to be_enabled
    end

    it 'is disabled in production without a webhook' do
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(described_class).to receive(:error_webhook_url).and_return(nil)

      expect(described_class).not_to be_enabled
    end
  end
end
