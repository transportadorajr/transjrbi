require 'rails_helper'

RSpec.describe ExportPlantForm do
  let!(:tenant) { create(:tenant) }
  let!(:arcelor) { create(:customer_group, tenant:, name: 'ARCELORMITTAL') }

  describe '#save' do
    it 'creates an active plant with one city per line' do
      form = described_class.new(tenant:, customer_group_id: arcelor.id, name: '  Sul   Fluminense ', cities: "RESENDE\n\nBarra Mansa\nresende\n")

      expect { expect(form.save).to be(true) }.to change(ExportPlant, :count).by(1)

      expect(ExportPlant.last).to have_attributes(tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: ['RESENDE', 'Barra Mansa'])
      expect(ExportPlant.last).to be_activated
    end

    it 'requires the group, the name and at least one city' do
      form = described_class.new(tenant:, name: '', cities: "\n")

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Grupo de clientes não pode ficar em branco', 'Nome não pode ficar em branco',
                                               'Cidades de origem não pode ficar em branco'])
    end

    it 'rejects a group of another tenant' do
      form = described_class.new(tenant:, customer_group_id: create(:customer_group).id, name: 'Ipatinga', cities: 'IPATINGA')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Grupo de clientes não pertence a esta empresa'])
    end

    context 'when the group already has a plant' do
      let!(:plant) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Juiz de Fora', cities: ['JUIZ DE FORA']) }

      it 'rejects the same name' do
        form = described_class.new(tenant:, customer_group_id: arcelor.id, name: 'juiz de fora', cities: 'PIRACICABA')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Nome já está em uso'])
      end

      it 'rejects a city of another active plant of the group' do
        form = described_class.new(tenant:, customer_group_id: arcelor.id, name: 'Minas', cities: "Juiz de Fora\nIPATINGA")

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Cidades de origem Juiz de Fora já estão em outra planta ativa deste grupo'])
      end

      it 'accepts the city when the other plant is inactive' do
        plant.update!(activated: false)

        expect(described_class.new(tenant:, customer_group_id: arcelor.id, name: 'Minas', cities: 'JUIZ DE FORA').save).to be(true)
      end

      it 'accepts the city of a plant of another group' do
        usiminas = create(:customer_group, tenant:, name: 'USIMINAS')

        expect(described_class.new(tenant:, customer_group_id: usiminas.id, name: 'Juiz de Fora', cities: 'JUIZ DE FORA').save).to be(true)
      end

      it 'updates the plant keeping its own cities' do
        form = described_class.for_export_plant(plant)
        form.assign_attributes(cities: "JUIZ DE FORA\nSANTOS DUMONT", active: false)

        expect { expect(form.save).to be(true) }.not_to change(ExportPlant, :count)
        expect(plant.reload.cities).to eq(['JUIZ DE FORA', 'SANTOS DUMONT'])
        expect(plant).not_to be_activated
      end
    end
  end

  describe '.for_export_plant' do
    let!(:plant) { create(:export_plant, tenant:, customer_group: arcelor, name: 'Sul Fluminense', cities: %w[RESENDE BARRA]) }

    it 'fills the cities one per line' do
      form = described_class.for_export_plant(plant)

      expect(form).to have_attributes(customer_group_id: arcelor.id, name: 'Sul Fluminense', cities: "RESENDE\nBARRA", active: true)
    end
  end
end
