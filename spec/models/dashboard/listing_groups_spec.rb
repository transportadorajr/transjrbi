require 'rails_helper'

RSpec.describe Dashboard::ListingGroups do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 7100, name: 'USIMINAS IPATINGA', customer_group: usiminas) }
  let!(:loose_customer) { create(:atua_customer, tenant:, code: 7300, name: 'AVULSO', customer_group: nil) }

  def row_values(groups)
    (groups.rows + [groups.total]).map { |row| [row.key, row.label, row.count, row.gross.format, row.net&.format] }
  end

  def add_document(number, freight_cents:, plate: 'AAA1A11', driver_code: 10, driver_name: 'JOSE SILVA', taker: usiminas_customer, **attributes)
    create(:atua_transport_document, tenant:, number:, series: 1, branch_name: 'JR', freight_cents:, plate:, driver_code:, driver_name:,
                                     taker_code: taker&.code, taker_name: taker&.name, **attributes)
  end

  describe '.sanitize_dimension' do
    it 'keeps a known dimension and drops any other value' do
      expect(described_class.sanitize_dimension('vehicle')).to eq('vehicle')
      expect(described_class.sanitize_dimension('origin')).to be_nil
      expect(described_class.sanitize_dimension(nil)).to be_nil
    end
  end

  describe '.for_transport_documents' do
    subject(:groups) { described_class.for_transport_documents(tenant.atua_transport_documents.order(:number), dimension:, net:) }

    let(:net) { true }

    before do
      add_document('1', freight_cents: 100_000)
      add_document('2', freight_cents: 300_000, plate: 'BBB2B22', driver_code: 20, driver_name: 'MARIA SOUZA')
      add_document('3', freight_cents: 50_000, plate: nil, driver_code: nil, driver_name: nil, taker: loose_customer)
      create(:freight_expense, tenant:, transport_document: Atua::TransportDocument.find_by(number: '2'), amount_cents: 100_000)
      create(:atua_transport_document, tenant: other_tenant, number: '4', freight_cents: 900_000, plate: 'AAA1A11')
    end

    context 'when grouped by customer group' do
      let(:dimension) { 'customer_group' }

      it 'sums the documents of each group of the taker, the biggest gross first' do
        expect(groups).to be_grouped
        expect(groups.filter_param).to eq('customer_group_id')
        expect(row_values(groups)).to eq(
          [
            [usiminas.id.to_s, 'USIMINAS', 2, 'R$ 4.000,00', 'R$ 3.000,00'],
            [nil, 'Sem grupo', 1, 'R$ 500,00', 'R$ 500,00'],
            [nil, 'Total', 3, 'R$ 4.500,00', 'R$ 3.500,00'],
          ],
        )
      end
    end

    context 'when grouped by customer' do
      let(:dimension) { 'customer' }

      it 'sums the documents of each taker' do
        expect(groups.filter_param).to eq('customer_code')
        expect(row_values(groups)).to eq(
          [
            ['7100', 'USIMINAS IPATINGA', 2, 'R$ 4.000,00', 'R$ 3.000,00'],
            ['7300', 'AVULSO', 1, 'R$ 500,00', 'R$ 500,00'],
            [nil, 'Total', 3, 'R$ 4.500,00', 'R$ 3.500,00'],
          ],
        )
      end
    end

    context 'when grouped by vehicle' do
      let(:dimension) { 'vehicle' }

      it 'sums the documents of each plate' do
        expect(groups.filter_param).to eq('plate')
        expect(row_values(groups)).to eq(
          [
            ['BBB2B22', 'BBB2B22', 1, 'R$ 3.000,00', 'R$ 2.000,00'],
            ['AAA1A11', 'AAA1A11', 1, 'R$ 1.000,00', 'R$ 1.000,00'],
            [nil, 'Sem placa', 1, 'R$ 500,00', 'R$ 500,00'],
            [nil, 'Total', 3, 'R$ 4.500,00', 'R$ 3.500,00'],
          ],
        )
      end
    end

    context 'when grouped by driver without access to the net freight' do
      let(:dimension) { 'driver' }
      let(:net) { false }

      it 'sums the gross freight of each driver and leaves the net freight out' do
        expect(groups.filter_param).to eq('driver_code')
        expect(row_values(groups)).to eq(
          [
            ['20', 'MARIA SOUZA', 1, 'R$ 3.000,00', nil],
            ['10', 'JOSE SILVA', 1, 'R$ 1.000,00', nil],
            [nil, 'Sem motorista', 1, 'R$ 500,00', nil],
            [nil, 'Total', 3, 'R$ 4.500,00', nil],
          ],
        )
      end
    end

    context 'without a dimension' do
      let(:dimension) { 'origin' }

      it 'is not grouped' do
        expect(groups).not_to be_grouped
      end
    end
  end

  describe '.for_manifests' do
    subject(:groups) { described_class.for_manifests(tenant.atua_manifests.order(:code), dimension:, net: true) }

    def link(manifest, number)
      create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: number, transport_document_series: 1,
                                      branch_name: 'JR')
    end

    before do
      first_trip = create(:atua_manifest, tenant:, code: 41_001, branch_name: 'JR', plate: 'AAA1A11')
      second_trip = create(:atua_manifest, tenant:, code: 41_002, branch_name: 'JR', plate: 'AAA1A11')
      third_trip = create(:atua_manifest, tenant:, code: 41_003, branch_name: 'JR', plate: 'BBB2B22')
      add_document('1', freight_cents: 100_000)
      add_document('2', freight_cents: 200_000, taker: loose_customer)
      add_document('3', freight_cents: 400_000, plate: 'BBB2B22', driver_code: 20, driver_name: 'MARIA SOUZA')
      add_document('4', freight_cents: 800_000, canceled_at: Time.current)
      link(first_trip, '1')
      link(first_trip, '2')
      link(second_trip, '4')
      link(third_trip, '3')
    end

    context 'when grouped by vehicle' do
      let(:dimension) { 'vehicle' }

      it 'counts the manifests of each plate and sums the freight of their valid transport documents' do
        expect(row_values(groups)).to eq(
          [
            ['BBB2B22', 'BBB2B22', 1, 'R$ 4.000,00', 'R$ 4.000,00'],
            ['AAA1A11', 'AAA1A11', 1, 'R$ 3.000,00', 'R$ 3.000,00'],
            [nil, 'Total', 2, 'R$ 7.000,00', 'R$ 7.000,00'],
          ],
        )
      end
    end

    context 'when grouped by customer group' do
      let(:dimension) { 'customer_group' }

      it 'counts a manifest once in every group it carries freight for' do
        expect(row_values(groups)).to eq(
          [
            [usiminas.id.to_s, 'USIMINAS', 2, 'R$ 5.000,00', 'R$ 5.000,00'],
            [nil, 'Sem grupo', 1, 'R$ 2.000,00', 'R$ 2.000,00'],
            [nil, 'Total', 2, 'R$ 7.000,00', 'R$ 7.000,00'],
          ],
        )
      end
    end
  end
end
