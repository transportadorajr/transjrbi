require 'rails_helper'
require Rails.root.join('db/migrate/20261102221419_discard_excluded_plate_records')

RSpec.describe DiscardExcludedPlateRecords do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  context 'with an imported document and manifest of the excluded plate' do
    let!(:tenant) { create(:tenant) }
    let!(:document) { create(:atua_transport_document, tenant:, plate: 'BAM2A26') }
    let!(:manifest) { create(:atua_manifest, tenant:, plate: 'BAM2A26') }

    it 'removes them and schedules the empty legs again' do
      expect { migration.up }.to have_enqueued_job(EmptyLegs::CalculateJob).with(tenant.id, nil)

      expect(document.reload.removed_from_atua_at).to be_present
      expect(manifest.reload.removed_from_atua_at).to be_present
    end
  end
end
