require 'rails_helper'
require Rails.root.join('db/migrate/20261125190852_enable_feature_flags_globally')

RSpec.describe EnableFeatureFlagsGlobally do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  it 'enables every product feature for all tenants and can run again' do
    2.times { migration.up }

    expect(described_class::FEATURES).to all(satisfy { |feature| Flipper.enabled?(feature, tenant) })
  end

  it 'leaves the Atua capture flags untouched' do
    migration.up

    expect(Flipper.enabled?(Atua::FEATURE, tenant)).to be(false)
    expect(Flipper.enabled?(Atua::PRODUCTION_ACCESS_FEATURE)).to be(false)
  end

  it 'covers every feature flag checked by the product' do
    product_features = [
      Dashboard::Trip::FEATURE, Dashboard::RevenueProjection::FEATURE, Dashboard::Goals::FEATURE,
      Dashboard::Freight::COMPARISON_FEATURE, ExportPlant::FEATURE, MaintenanceOrder::FEATURE,
      MaintenanceOrderSignature::FEATURE, Hr::FEATURE, XlsxExport::FEATURE
    ]

    expect(described_class::FEATURES).to match_array(product_features)
  end

  it 'cannot be rolled back' do
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
