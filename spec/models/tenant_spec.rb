require 'rails_helper'

RSpec.describe Tenant do
  describe 'atua_url validation' do
    it 'accepts a blank url' do
      expect(build(:tenant, atua_url: nil)).to be_valid
    end

    it 'accepts an https url' do
      expect(build(:tenant, atua_url: 'https://transportadora.atua.com.br/adm')).to be_valid
    end

    it 'accepts a local http url' do
      expect(build(:tenant, atua_url: 'http://localhost:4567/adm')).to be_valid
    end

    it 'rejects a value that is not an http url' do
      tenant = build(:tenant, atua_url: 'transportadora.atua.com.br')

      expect(tenant).not_to be_valid
      expect(tenant.errors.full_messages).to eq(['URL da Atua não é válido'])
    end
  end
end
