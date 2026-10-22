require 'rails_helper'
require Rails.root.join('db/migrate/20261022134410_backfill_macro_regions')

RSpec.describe BackfillMacroRegions do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with two tenants' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }

    it 'registers the default regions of every tenant' do
      expect { migration.up }.to change(MacroRegion, :count).by(10)

      expect(tenant.macro_regions.count).to eq(5)
      expect(other_tenant.macro_regions.count).to eq(5)
    end

    it 'can run again without duplicating the regions' do
      migration.up

      expect { migration.up }.not_to change(MacroRegion, :count)
    end
  end
end
