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

  describe '.export_field' do
    let!(:tenant) { create(:tenant) }
    let!(:macro_region) { create(:macro_region, tenant:, name: 'Vale do Aço', state: 'MG', city_names: ['Ipatinga']) }
    let(:city) { tenant.cities.find_by!(name: 'Ipatinga') }

    it 'exports the value read by its block under the header of the attribute' do
      field = City.export_columns.first

      expect(field.to_h).to eq(header: 'Macro região', type: :string)
      expect(field.value(city)).to eq('Vale do Aço')
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

    it 'has a translated header for every exported column of every listing' do
      models = [Atua::TransportDocument, Atua::Manifest, Atua::Expense, Atua::Customer, Atua::Vehicle, FreightExpense, User, CustomerGroup,
                ProductGroup, CommissionRule, TonnageRate, RouteDistance, TruckGroup, MacroRegion, City, ExcludedIssuer, Holiday]

      expect(models.flat_map { |model| model.export_columns.reject(&:translated?).map { |column| "#{model.name}##{column.name}" } }).to be_empty
    end

    it 'puts the name of the associated record where its foreign key was' do
      names = City.export_columns.map(&:name)

      expect(names).to eq(%w[macro_region name state created_at updated_at])
    end

    it 'appends the fields that do not replace a foreign key after the columns' do
      names = ExcludedIssuer.export_columns.map(&:name)

      expect(names).to eq(%w[code name created_at updated_at documents_count freight])
    end

    it 'leaves out the type of a polymorphic association' do
      names = Atua::Expense.export_columns.map(&:name)

      expect(names).to include('allocation', 'origin')
      expect(names).not_to include('cost_object_type', 'cost_object_id')
    end
  end
end
