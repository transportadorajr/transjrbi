require 'rails_helper'

RSpec.describe ExportShortcutForm do
  let!(:tenant) { create(:tenant) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:juiz_de_fora) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }
  let!(:ipatinga) { create(:export_plant, tenant:, customer_group: usiminas, name: 'Ipatinga', cities: ['IPATINGA']) }

  describe '#save' do
    it 'creates a shortcut with the chosen group, plants and countries' do
      form = described_class.new(tenant:, name: '  Arcelor   Juiz de Fora ', customer_group_id: arcelor.id, export_plant_ids: ['', juiz_de_fora.id.to_s],
                                 countries: ['', 'paraguay', 'argentina'], position: 2)

      expect { expect(form.save).to be(true) }.to change(ExportShortcut, :count).by(1)

      expect(ExportShortcut.last).to have_attributes(tenant:, name: 'Arcelor Juiz de Fora', customer_group: arcelor, export_plant_ids: [juiz_de_fora.id],
                                                     countries: %w[paraguay argentina], position: 2)
      expect(ExportShortcut.last).to be_activated
    end

    it 'creates a shortcut of every export when nothing is chosen' do
      form = described_class.new(tenant:, name: 'Toda a exportação')

      expect(form.save).to be(true)
      expect(ExportShortcut.last).to have_attributes(customer_group: nil, export_plant_ids: [], countries: [])
    end

    it 'rejects a repeated name, plants of another group and unknown countries' do
      create(:export_shortcut, tenant:, name: 'Usiminas Ipatinga')
      form = described_class.new(tenant:, name: 'usiminas ipatinga', customer_group_id: arcelor.id, export_plant_ids: [ipatinga.id.to_s],
                                 countries: ['brasil'], position: -1)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(
        ['Ordem deve ser maior ou igual a 0', 'Nome já está em uso',
         'Plantas de origem devem ser plantas ativas desta empresa e do cliente escolhido', 'Países de destino não são válidos'],
      )
    end

    it 'rejects a group and a plant of another tenant' do
      other_plant = create(:export_plant)
      form = described_class.new(tenant:, name: 'Outro', customer_group_id: other_plant.customer_group_id, export_plant_ids: [other_plant.id])

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Cliente não pertence a esta empresa',
                                               'Plantas de origem devem ser plantas ativas desta empresa e do cliente escolhido'])
    end

    it 'updates a shortcut keeping its own name' do
      shortcut = create(:export_shortcut, tenant:, name: 'Arcelor', countries: ['paraguay'])
      form = described_class.for_export_shortcut(shortcut)
      form.assign_attributes(countries: %w[paraguay unknown], active: false)

      expect { expect(form.save).to be(true) }.not_to change(ExportShortcut, :count)
      expect(shortcut.reload.countries).to eq(%w[paraguay unknown])
      expect(shortcut).not_to be_activated
    end
  end
end
