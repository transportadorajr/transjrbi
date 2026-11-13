require 'rails_helper'

RSpec.describe OwnFleetForm do
  let(:tenant) { create(:tenant) }

  describe '.for_tenant' do
    it 'lists the plates of the fleet one per line' do
      create(:own_fleet, tenant:, plates: %w[AJR4391 RHJ5A50])

      expect(described_class.for_tenant(tenant).plates).to eq("AJR4391\nRHJ5A50")
    end

    it 'starts empty when the tenant has no fleet' do
      expect(described_class.for_tenant(tenant).plates).to eq('')
    end
  end

  describe '#plate_list' do
    it 'reads the plates from lines of the RNTRC statement and ignores the rest' do
      form = described_class.new(tenant:, plates: <<~TEXT)
        1 ALC-6D72/PR Automotor CAMINHÃO TRATOR 00810814129 NÃO PRÓPRIO ATIVO
        2 AJR-4391/PR Automotor CAMINHÃO TRATOR 00751364860 NÃO PRÓPRIO ATIVO
        RNTRC: 046194795 ETC
      TEXT

      expect(form.plate_list).to eq(%w[AJR4391 ALC6D72])
    end

    it 'accepts plates separated by commas, semicolons and spaces, removing the duplicates' do
      form = described_class.new(tenant:, plates: 'rhj5a50, AJR4391;BCN-3I00 AJR-4391')

      expect(form.plate_list).to eq(%w[AJR4391 BCN3I00 RHJ5A50])
    end
  end

  describe '#save' do
    it 'creates the fleet of the tenant' do
      form = described_class.for_tenant(tenant)
      form.plates = 'AJR-4391/PR RHJ5A50'

      expect { form.save }.to change(OwnFleet, :count).by(1)
      expect(OwnFleet.last).to have_attributes(tenant:, plates: %w[AJR4391 RHJ5A50])
    end

    it 'replaces the plates of an existing fleet' do
      own_fleet = create(:own_fleet, tenant:, plates: %w[AJR4391])
      form = described_class.for_tenant(tenant)
      form.plates = 'BCN3I00'

      expect { form.save }.not_to change(OwnFleet, :count)
      expect(own_fleet.reload.plates).to eq(%w[BCN3I00])
    end

    it 'clears the fleet with an empty list' do
      own_fleet = create(:own_fleet, tenant:, plates: %w[AJR4391])
      form = described_class.for_tenant(tenant)
      form.plates = ''

      expect(form.save).to be(true)
      expect(own_fleet.reload.plates).to eq([])
    end
  end
end
