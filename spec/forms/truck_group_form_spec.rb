require 'rails_helper'

RSpec.describe TruckGroupForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    let!(:document) { create(:atua_transport_document, tenant:, axles: 9, freight_cents: 1_000_000) }

    it 'creates the group and calculates the fuel of its transport documents' do
      form = described_class.new(tenant:, name: ' Rodotrem ', axles: ['', '9'], fuel_percentage: '32.5', active: '1')

      expect { expect(form.save).to be(true) }.to change(TruckGroup, :count).by(1).and change(FreightExpense, :count).by(1)

      truck_group = TruckGroup.last
      expect(truck_group).to have_attributes(tenant:, name: 'Rodotrem', axles: [9], fuel_percentage: BigDecimal('32.5'), activated?: true)
      expect(FreightExpense.last).to have_attributes(transport_document: document, kind_type: 'fuel', truck_group:, amount_cents: 325_000)
    end

    it 'creates the group of the remaining axles ignoring the checked axle counts' do
      create(:truck_group, tenant:, axles: [9], fuel_percentage: 0)
      truck = create(:atua_transport_document, tenant:, axles: 4, freight_cents: 1_000_000)
      form = described_class.new(tenant:, name: 'Outros', axles: ['', '3'], remaining_axles: '1', fuel_percentage: '33', active: '1')

      expect { expect(form.save).to be(true) }.to change(TruckGroup, :count).by(1).and change(FreightExpense, :count).by(1)

      truck_group = TruckGroup.last
      expect(truck_group).to have_attributes(name: 'Outros', axles: [], remaining_axles: true, fuel_percentage: BigDecimal('33'))
      expect(FreightExpense.last).to have_attributes(transport_document: truck, truck_group:, amount_cents: 330_000)
      expect(FreightExpense.exists?(transport_document: document)).to be(false)
    end

    it 'creates a group of plates normalizing them and calculates the fuel by the plate' do
      truck = create(:atua_transport_document, tenant:, plate: 'BAV5A04', axles: 6, freight_cents: 1_000_000)
      form = described_class.new(tenant:, name: 'Utinga', axles: [''], plates: "bav-5a04\nEVO8C24, BAV5A04", fuel_percentage: '28', active: '1')

      expect { expect(form.save).to be(true) }.to change(TruckGroup, :count).by(1).and change(FreightExpense, :count).by(1)

      truck_group = TruckGroup.last
      expect(truck_group).to have_attributes(name: 'Utinga', axles: [], plates: %w[BAV5A04 EVO8C24], fuel_percentage: BigDecimal('28'))
      expect(FreightExpense.last).to have_attributes(transport_document: truck, truck_group:, amount_cents: 280_000)
    end

    it 'rejects a plate with an invalid format' do
      form = described_class.new(tenant:, name: 'Utinga', plates: "BAV5A04\nEVO", fuel_percentage: '28')

      expect { expect(form.save).to be_falsey }.not_to change(TruckGroup, :count)
      expect(form.errors.full_messages).to eq(['Placas EVO não são placas válidas'])
    end

    it 'ignores the plates of the group of the remaining axles' do
      form = described_class.new(tenant:, name: 'Outros', plates: 'BAV5A04', remaining_axles: '1', fuel_percentage: '33')

      expect(form.save).to be(true)
      expect(TruckGroup.last.plates).to eq([])
    end

    it 'rejects a group without the required fields' do
      form = described_class.new(tenant:, axles: [''], fuel_percentage: '')

      expect { expect(form.save).to be_falsey }.not_to change(TruckGroup, :count)
      expect(form.errors.full_messages).to contain_exactly(
        'Nome não pode ficar em branco', 'Quantidades de eixos não pode ficar em branco',
        'Combustível sobre o frete (%) não pode ficar em branco'
      )
    end

    it 'rejects an axle count out of the options and a fuel percentage above 100' do
      form = described_class.new(tenant:, name: 'Bitrem', axles: ['12'], fuel_percentage: '120')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to contain_exactly(
        'Quantidades de eixos não está incluído na lista', 'Combustível sobre o frete (%) deve ser menor ou igual a 100'
      )
    end

    it 'rejects a fuel percentage written as text' do
      %w[abc 32,5].each do |fuel_percentage|
        form = described_class.new(tenant:, name: 'Bitrem', axles: ['7'], fuel_percentage:)

        expect { expect(form.save).to be_falsey }.not_to change(TruckGroup, :count)
        expect(form.errors.full_messages).to eq(['Combustível sobre o frete (%) não é um número'])
      end
    end

    it 'rejects a fuel percentage below zero' do
      form = described_class.new(tenant:, name: 'Bitrem', axles: ['7'], fuel_percentage: '-1')

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Combustível sobre o frete (%) deve ser maior ou igual a 0'])
    end

    context 'with other groups of the tenant' do
      let!(:rodotrem) { create(:truck_group, tenant:) }

      before { create(:truck_group, :ls, tenant:, name: 'LS antigo', activated_at: nil) }

      it 'rejects a name already in use by the tenant' do
        form = described_class.new(tenant:, name: 'Rodotrem', axles: ['7'], fuel_percentage: '30')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Nome já está em uso por outro grupo'])
      end

      it 'rejects an axle count already in another active group' do
        form = described_class.new(tenant:, name: 'Bitrem', axles: %w[7 9], fuel_percentage: '30')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Quantidades de eixos 9 já estão em outro grupo ativo'])
      end

      it 'rejects a plate already in another active group' do
        create(:truck_group, :utinga, tenant:)
        form = described_class.new(tenant:, name: 'Santo Andre', plates: 'BAV5A04', fuel_percentage: '30')

        expect(form.save).to be_falsey
        expect(form.errors.full_messages).to eq(['Placas BAV5A04 já estão em outro grupo ativo'])
      end

      it 'loads the plates when editing a group of plates' do
        form = described_class.for_truck_group(create(:truck_group, :utinga, tenant:))

        expect(form.plates).to eq("BAV5A04\nEVO8C24")
        expect(form).to be_valid
      end

      it 'accepts an axle count of an inactive group' do
        form = described_class.new(tenant:, name: 'LS', axles: ['6'], fuel_percentage: '30')

        expect(form.save).to be(true)
      end

      it 'accepts an inactive group with an axle count already in use' do
        form = described_class.new(tenant:, name: 'Rodotrem antigo', axles: ['9'], fuel_percentage: '30', active: '0')

        expect(form.save).to be(true)
        expect(TruckGroup.last.activated?).to be(false)
      end

      context 'with an active group of the remaining axles' do
        let!(:others) { create(:truck_group, :others, tenant:) }

        it 'rejects another active group of the remaining axles' do
          form = described_class.new(tenant:, name: 'Demais', remaining_axles: '1', fuel_percentage: '30')

          expect { expect(form.save).to be_falsey }.not_to change(TruckGroup, :count)
          expect(form.errors.full_messages).to eq(['Abrange os demais eixos já está em outro grupo ativo'])
        end

        it 'accepts an inactive group of the remaining axles' do
          form = described_class.new(tenant:, name: 'Demais', remaining_axles: '1', fuel_percentage: '30', active: '0')

          expect(form.save).to be(true)
        end

        it 'updates the group of the remaining axles' do
          form = described_class.for_truck_group(others)

          expect(form).to have_attributes(axles: [], remaining_axles: true, fuel_percentage: '33')

          form.assign_attributes(fuel_percentage: '30')

          expect(form.save).to be(true)
          expect(others.reload.fuel_percentage).to eq(BigDecimal('30'))
        end
      end

      it 'updates the group keeping its own name and axles and recalculates the fuel' do
        form = described_class.for_truck_group(rodotrem)

        expect(form).to have_attributes(axles: [9], fuel_percentage: '35', active: true)

        expect(form.fuel_valid_month).to eq(Date.current.strftime('%Y-%m'))

        form.assign_attributes(fuel_valid_month: 'abc')
        expect(form.save).to be_falsey
        expect(form.errors).to be_of_kind(:fuel_valid_month, :invalid)

        form.assign_attributes(fuel_valid_month: 1.month.from_now.strftime('%Y-%m'))
        expect(form.save).to be_falsey
        expect(form.errors).to be_of_kind(:fuel_valid_month, :future)

        form.assign_attributes(fuel_valid_month: Date.current.strftime('%Y-%m'), fuel_percentage: '40')

        expect { expect(form.save).to be(true) }.not_to change(TruckGroup, :count)
        expect(rodotrem.reload.fuel_percentage).to eq(BigDecimal('40'))
        expect(FreightExpense.fuel.sole).to have_attributes(transport_document: document, amount_cents: 400_000)
      end
    end
  end
end
