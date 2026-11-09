require 'rails_helper'

RSpec.describe XlsxExport do
  let(:credentials_url) { nil }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:xlsx_export, :url).and_return(credentials_url)
  end

  def in_environment(name, &)
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(name))
    ClimateControl.modify(XLSX_EXPORT_URL: nil, &)
  end

  describe '.url' do
    context 'in production' do
      it 'uses the URL of the environment variable' do
        in_environment('production') do
          ClimateControl.modify(XLSX_EXPORT_URL: 'http://xlsx:4000') do
            expect(described_class.url).to eq('http://xlsx:4000')
          end
        end
      end

      context 'with the URL in the credentials' do
        let(:credentials_url) { 'http://planilhas.interno:4000' }

        it 'uses the URL of the credentials' do
          in_environment('production') { expect(described_class.url).to eq('http://planilhas.interno:4000') }
        end
      end

      it 'refuses to fall back to localhost when no URL is configured' do
        in_environment('production') do
          expect { described_class.url }.to raise_error(
            XlsxExport::ConfigurationError,
            'Configuração do serviço de planilhas incompleta: defina XLSX_EXPORT_URL (ou xlsx_export.url nos credentials).',
          )
        end
      end
    end

    context 'in development and test' do
      it 'falls back to the local service when no URL is configured' do
        expect(%w[development test].map { |name| in_environment(name) { described_class.url } }).to eq(%w[http://localhost:4000] * 2)
      end

      it 'prefers the URL of the environment variable' do
        in_environment('development') do
          ClimateControl.modify(XLSX_EXPORT_URL: 'http://127.0.0.1:4555') { expect(described_class.url).to eq('http://127.0.0.1:4555') }
        end
      end
    end
  end

  describe 'ConfigurationError' do
    it 'is an export error, so the listing shows the failure message instead of crashing' do
      expect(XlsxExport::ConfigurationError.new).to be_a(XlsxExport::Error)
    end
  end
end
