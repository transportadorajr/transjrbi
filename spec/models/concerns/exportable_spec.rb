require 'rails_helper'

RSpec.describe Exportable do
  let(:exportable_users) do
    Class.new(ApplicationRecord) do
      self.table_name = 'users'
      include Exportable

      class << self
        def name
          'User'
        end
      end
    end
  end

  describe '.export_columns' do
    it 'exports every column of the vehicle but the ids, the technical columns and the digit-only documents' do
      names = Atua::Vehicle.export_columns.map(&:name)

      expect(names).to eq(Atua::Vehicle.column_names - %w[id tenant_id atua_import_id raw_data owner_document_digits driver_document_digits])
    end

    it 'never exports the credentials and the network addresses of a user' do
      names = exportable_users.export_columns.map(&:name)

      expect(names).to include('name', 'email', 'user_type', 'last_sign_in_at')
      expect(names).not_to include('id', 'tenant_id', 'encrypted_password', 'reset_password_token', 'confirmation_token',
                                   'current_sign_in_ip', 'last_sign_in_ip')
    end

    it 'has a translated header for every exported column of the vehicle' do
      expect(Atua::Vehicle.export_columns.reject(&:translated?).map(&:name)).to be_empty
    end
  end
end
