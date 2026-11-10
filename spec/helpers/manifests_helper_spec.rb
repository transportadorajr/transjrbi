require 'rails_helper'

RSpec.describe ManifestsHelper do
  describe '#manifest_identity' do
    it 'shows the number with the plate of the truck' do
      manifest = build(:atua_manifest, number: '41462', plate: 'RHJ4E07')

      expect(helper.manifest_identity(manifest)).to eq('41462 - RHJ4E07')
    end

    it 'shows only the number when the manifest has no plate' do
      manifest = build(:atua_manifest, number: '41462', plate: nil)

      expect(helper.manifest_identity(manifest)).to eq('41462')
    end
  end
end
