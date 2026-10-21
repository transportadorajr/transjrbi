require 'rails_helper'

RSpec.describe Atua::Configuration do
  let(:credentials) { { base_url: 'http://localhost:4567/adm', username: 'transjr', password: 'secret-password' } }

  before { allow(Rails.application.credentials).to receive(:atua).and_return(credentials) }

  describe '.for' do
    context 'with complete credentials' do
      it 'reads the base url, username and password' do
        configuration = described_class.for

        expect(configuration.base_url).to eq('http://localhost:4567/adm')
        expect(configuration.username).to eq('transjr')
        expect(configuration.password).to eq('secret-password')
        expect(configuration.origin).to eq('http://localhost:4567')
      end
    end

    context 'with a tenant that has its own Atua url' do
      let(:tenant) { build(:tenant, atua_url: 'http://127.0.0.1:4567/adm/') }

      it 'prefers the url of the tenant' do
        expect(described_class.for(tenant).base_url).to eq('http://127.0.0.1:4567/adm')
      end
    end

    context 'with a tenant without Atua url' do
      let(:tenant) { build(:tenant, atua_url: nil) }

      it 'falls back to the base url of the credentials' do
        expect(described_class.for(tenant).base_url).to eq('http://localhost:4567/adm')
      end
    end

    context 'when a key is missing' do
      let(:credentials) { { base_url: 'http://localhost:4567/adm', username: 'transjr', password: '' } }

      it 'raises a configuration error naming the key without its values' do
        expect { described_class.for }.to raise_error(Atua::ConfigurationError) { |error|
          expect(error.message).to eq('Configuração da Atua incompleta: falta password.')
          expect(error.message).not_to include('transjr')
        }
      end
    end

    context 'when several keys are missing' do
      let(:credentials) { { base_url: 'http://localhost:4567/adm' } }

      it 'names every missing key' do
        expect { described_class.for }.to raise_error(Atua::ConfigurationError, 'Configuração da Atua incompleta: falta username, password.')
      end
    end

    context 'when the credentials have no Atua section' do
      let(:credentials) { nil }

      it 'names every key' do
        expect { described_class.for }.to raise_error(Atua::ConfigurationError, 'Configuração da Atua incompleta: falta base_url, username, password.')
      end
    end

    context 'when the base url is not an http url' do
      let(:credentials) { { base_url: 'transjr.atua.com.br/adm', username: 'transjr', password: 'secret-password' } }

      it 'raises a configuration error' do
        expect { described_class.for }.to raise_error(Atua::ConfigurationError, 'A URL base da Atua não é uma URL http/https válida.')
      end
    end

    context 'when the base url points to a remote host outside production' do
      let(:credentials) { { base_url: 'https://transjr.atua.com.br/adm', username: 'transjr', password: 'secret-password' } }

      it 'blocks the remote host' do
        expect { described_class.for }.to raise_error(Atua::ConfigurationError, /transjr\.atua\.com\.br/)
      end

      it 'allows the remote host only when explicitly requested' do
        expect(described_class.for(allow_remote_host: true).base_url).to eq('https://transjr.atua.com.br/adm')
      end

      it 'allows the remote host in production' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))

        expect(described_class.for.origin).to eq('https://transjr.atua.com.br')
      end
    end

    context 'when ATUA_BASE_URL is set' do
      let(:credentials) { { base_url: 'https://transjr.atua.com.br/adm', username: 'transjr', password: 'secret-password' } }

      it 'overrides only the base url in development' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('development'))

        ClimateControl.modify(ATUA_BASE_URL: 'http://localhost:4567/adm') do
          configuration = described_class.for(build(:tenant, atua_url: 'https://transjr.atua.com.br/adm'))

          expect(configuration.base_url).to eq('http://localhost:4567/adm')
          expect(configuration.username).to eq('transjr')
          expect(configuration.password).to eq('secret-password')
        end
      end

      it 'is ignored outside development' do
        ClimateControl.modify(ATUA_BASE_URL: 'http://localhost:4567/adm') do
          expect { described_class.for }.to raise_error(Atua::ConfigurationError, /transjr\.atua\.com\.br/)
        end
      end
    end

    context 'when the production access flag is on', flipper: :atua_production_access do
      let(:credentials) { { base_url: 'https://transjr.atua.com.br/adm', username: 'transjr', password: 'secret-password' } }
      let(:tenant) { build(:tenant, atua_url: 'https://transjr.atua.com.br/adm') }

      before { allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('development')) }

      it 'reaches the production Atua ignoring ATUA_BASE_URL' do
        ClimateControl.modify(ATUA_BASE_URL: 'http://localhost:4567/adm') do
          configuration = described_class.for(tenant)

          expect(configuration.base_url).to eq('https://transjr.atua.com.br/adm')
          expect(configuration.source_type).to eq(:production)
        end
      end
    end

    context 'when the production access flag is off' do
      let(:credentials) { { base_url: 'https://transjr.atua.com.br/adm', username: 'transjr', password: 'secret-password' } }
      let(:tenant) { build(:tenant, atua_url: 'https://transjr.atua.com.br/adm') }

      before { allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('development')) }

      it 'keeps the mock' do
        ClimateControl.modify(ATUA_BASE_URL: 'http://localhost:4567/adm') do
          configuration = described_class.for(tenant)

          expect(configuration.base_url).to eq('http://localhost:4567/adm')
          expect(configuration.source_type).to eq(:mock)
        end
      end

      it 'keeps blocking the remote host' do
        expect { described_class.for(tenant) }.to raise_error(Atua::ConfigurationError, /transjr\.atua\.com\.br/)
      end
    end
  end

  describe 'device cookie' do
    let(:device_cookie) { 'c_ds_dispositivo_transjr_9430=token123' }

    it 'has no device cookie by default' do
      expect(described_class.for.device_cookie).to be_nil
    end

    it 'reads the device cookie from the tenant' do
      tenant = build(:tenant, atua_device_token: device_cookie)

      expect(described_class.for(tenant).device_cookie).to eq(device_cookie)
    end

    it 'prefers the ATUA_DEVICE_COOKIE override' do
      tenant = build(:tenant, atua_device_token: 'c_ds_dispositivo_transjr_9430=stored')

      ClimateControl.modify(ATUA_DEVICE_COOKIE: device_cookie) do
        expect(described_class.for(tenant).device_cookie).to eq(device_cookie)
      end
    end

    it 'reads the device hash from the tenant' do
      expect(described_class.for(build(:tenant, atua_device_hash: 'abc123hash')).device_hash).to eq('abc123hash')
    end

    it 'reads the device hash from the credentials when the tenant has none' do
      credentials[:device_hash] = 'credentials-hash'

      expect(described_class.for(build(:tenant, atua_device_hash: nil)).device_hash).to eq('credentials-hash')
      expect(described_class.for.device_hash).to eq('credentials-hash')
    end

    it 'prefers the device hash of the tenant over the credentials' do
      credentials[:device_hash] = 'credentials-hash'

      expect(described_class.for(build(:tenant, atua_device_hash: 'stored-hash')).device_hash).to eq('stored-hash')
    end

    it 'reads the device cookie from the credentials when the tenant has none' do
      credentials[:device_cookie] = device_cookie

      expect(described_class.for(build(:tenant, atua_device_token: nil)).device_cookie).to eq(device_cookie)
    end

    it 'prefers the ATUA_DEVICE_HASH override' do
      tenant = build(:tenant, atua_device_hash: 'stored-hash')

      ClimateControl.modify(ATUA_DEVICE_HASH: 'env-hash') do
        expect(described_class.for(tenant).device_hash).to eq('env-hash')
      end
    end
  end

  describe '#inspect' do
    it 'does not show the password' do
      expect(described_class.for.inspect).not_to include('secret-password')
    end
  end
end
