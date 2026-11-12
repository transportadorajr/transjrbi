require 'rails_helper'

RSpec.describe Export::Column do
  let!(:tenant) { create(:tenant) }

  describe '.for' do
    it 'maps each database type to the type of the spreadsheet cell' do
      types = %w[number freight_cents weight_tons issued_at posted_on vehicle_sale result_margin_percentage].index_with do |name|
        described_class.for(Atua::TransportDocument, name).type
      end

      expect(types).to eq(
        'number' => :string, 'freight_cents' => :money, 'weight_tons' => :decimal, 'issued_at' => :datetime, 'posted_on' => :date,
        'vehicle_sale' => :boolean, 'result_margin_percentage' => :percentage
      )
    end

    it 'exports enums and arrays as text' do
      expect(described_class.for(User, 'user_type').type).to eq(:string)
      expect(described_class.for(TruckGroup, 'plates').type).to eq(:string)
      expect(described_class.for(TruckGroup, 'axles').type).to eq(:string)
    end
  end

  describe '#to_h' do
    it 'names a money column after its attribute and formats it with the currency of the locale' do
      expect(described_class.for(Atua::TransportDocument, 'freight_cents').to_h).to eq(header: 'Frete', type: :money, format: '"R$" #,##0.00')
    end

    it 'leaves the format of the other columns to the export service' do
      expect(described_class.for(Atua::Vehicle, 'plate').to_h).to eq(header: 'Placa', type: :string)
    end
  end

  describe '#translated?' do
    it 'tells whether the header comes from the locale files' do
      expect(described_class.for(Atua::Vehicle, 'plate')).to be_translated
      expect(described_class.for(Atua::ManifestDocument, 'manifest_code')).not_to be_translated
    end
  end

  describe '#value' do
    context 'with a transport document' do
      let!(:document) do
        create(:atua_transport_document, tenant:, freight_cents: 1_234_567, weight_tons: BigDecimal('32.5'), posted_on: Date.new(2026, 10, 2),
                                         issued_at: Time.zone.local(2026, 10, 1, 16, 45), vehicle_sale: false)
      end

      it 'serializes each value the way the export service reads it' do
        values = %w[freight_cents weight_tons posted_on issued_at vehicle_sale ciot].index_with do |name|
          described_class.for(Atua::TransportDocument, name).value(document)
        end

        expect(values).to eq(
          'freight_cents' => 1_234_567, 'weight_tons' => BigDecimal('32.5'), 'posted_on' => '2026-10-02', 'issued_at' => '2026-10-01T16:45:00-03:00',
          'vehicle_sale' => false, 'ciot' => nil
        )
      end
    end

    context 'with an enum and arrays' do
      let!(:user) { create(:user, tenant:, user_type: :owner) }
      let!(:truck_group) { create(:truck_group, tenant:, axles: [7, 9], plates: %w[EXU0F72 BEV4G50]) }

      it 'translates the enum and joins the arrays' do
        expect(described_class.for(User, 'user_type').value(user)).to eq('Proprietário')
        expect(described_class.for(TruckGroup, 'plates').value(truck_group)).to eq('EXU0F72, BEV4G50')
        expect(described_class.for(TruckGroup, 'axles').value(truck_group)).to eq('7, 9')
      end
    end
  end
end
