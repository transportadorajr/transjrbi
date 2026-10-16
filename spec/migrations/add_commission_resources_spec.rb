require 'rails_helper'
require Rails.root.join('db/migrate/20261015191720_add_commission_resources')

RSpec.describe AddCommissionResources do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'without the commission resources' do
    it 'creates the writable commission rules and the read-only freight expenses' do
      expect { migration.up }.to change(Resource, :count).by(2)

      expect(Resource.order(:slug).pluck(:slug, :name, :writable)).to eq(
        [['commission_rules', 'Regras de comissão', true], ['freight_expenses', 'Despesas de frete', false]],
      )
    end

    it 'can run again without duplicating the resources' do
      migration.up

      expect { migration.up }.not_to change(Resource, :count)
    end
  end

  context 'when rolling back' do
    let!(:operator) { create(:user) }

    before do
      migration.up
      create(:access, user: operator, tenant: operator.tenant, resource: Resource.find_by!(slug: 'freight_expenses'), reads: true)
    end

    it 'removes only the resources without permissions' do
      expect { migration.down }.to change(Resource, :count).by(-1)

      expect(Resource.pluck(:slug)).to contain_exactly('freight_expenses')
    end
  end
end
