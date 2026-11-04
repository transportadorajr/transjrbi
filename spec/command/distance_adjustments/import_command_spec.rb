require 'rails_helper'

RSpec.describe DistanceAdjustments::ImportCommand do
  let!(:tenant) { create(:tenant) }
  let!(:document) { create(:atua_transport_document, tenant:, number: '74120', distance_km: BigDecimal('300')) }

  context 'with a header and valid rows' do
    let(:path) { xlsx_file([['CT-e', 'KM'], [74_120, 450.5], ['74999', '610,00']]) }

    it 'creates the adjustments and applies the ones whose document exists' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.to change(DistanceAdjustment, :count).by(2)

      expect(result).to have_attributes(created: 2, updated: 0, applied: 1, pending: 1, duplicated_numbers: [], errors: [])
      expect(tenant.distance_adjustments.order(:transport_document_number).pluck(:transport_document_number, :distance_km))
        .to eq([['74120', BigDecimal('450.5')], ['74999', BigDecimal('610')]])
      expect(document.reload).to have_attributes(distance_km: BigDecimal('450.5'), original_distance_km: BigDecimal('300'))
    end
  end

  context 'with an adjustment already registered for a number of the file' do
    let!(:adjustment) { create(:distance_adjustment, tenant:, transport_document_number: '74120', distance_km: BigDecimal('400')) }
    let(:path) { xlsx_file([[74_120, 520]]) }

    it 'updates the adjustment and the distance of the document' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.not_to change(DistanceAdjustment, :count)

      expect(result).to have_attributes(created: 0, updated: 1, applied: 1, pending: 0)
      expect(adjustment.reload.distance_km).to eq(BigDecimal('520'))
      expect(document.reload).to have_attributes(distance_km: BigDecimal('520'), original_distance_km: BigDecimal('300'))
    end
  end

  context 'with the same file imported twice' do
    let(:path) { xlsx_file([[74_120, 450]]) }

    it 'does not duplicate the adjustments' do
      described_class.call(tenant, path, '.xlsx')

      expect { described_class.call(tenant, path, '.xlsx') }.not_to change(DistanceAdjustment, :count)
      expect(document.reload).to have_attributes(distance_km: BigDecimal('450'), original_distance_km: BigDecimal('300'))
    end
  end

  context 'with invalid rows' do
    let(:path) { xlsx_file([[74_120, 0], ['ABC', 300], [74_121, nil]]) }

    it 'reports each invalid row and imports nothing' do
      result = nil

      expect { result = described_class.call(tenant, path, '.xlsx') }.not_to change(DistanceAdjustment, :count)

      expect(result.errors).to eq(
        [
          'Linha 1: KM considerado deve ser maior que 0.',
          'Linha 2: Número do CT-e não é válido.',
          'Linha 3: KM considerado não pode ficar em branco.',
        ],
      )
      expect(document.reload.distance_km).to eq(BigDecimal('300'))
    end
  end

  context 'with a number shared by two transport documents' do
    before { create(:atua_transport_document, tenant:, number: '74120', series: 2, distance_km: BigDecimal('280')) }

    let(:path) { xlsx_file([[74_120, 450]]) }

    it 'warns about the shared number' do
      result = described_class.call(tenant, path, '.xlsx')

      expect(result.duplicated_numbers).to eq(['74120'])
      expect(tenant.atua_transport_documents.where(number: '74120').pluck(:distance_km)).to eq([BigDecimal('450'), BigDecimal('450')])
    end
  end

  context 'with a file that is not a spreadsheet' do
    let(:path) do
      Tempfile.new(%w[km .xlsx]).tap { |file| file.write('texto qualquer') && file.close }.path
    end

    it 'reports that the file could not be read' do
      result = described_class.call(tenant, path, '.xlsx')

      expect(result.errors.first).to start_with('Não foi possível ler a planilha:')
      expect(tenant.distance_adjustments).to be_empty
    end
  end
end
