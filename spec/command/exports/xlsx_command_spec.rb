require 'rails_helper'

RSpec.describe Exports::XlsxCommand do
  let!(:tenant) { create(:tenant) }
  let!(:truck) { create(:atua_vehicle, tenant:, plate: 'EXU0F72') }
  let(:client) { instance_double(XlsxExport::Client, workbook: 'xlsx bytes') }

  it 'sends every sheet to the export service and returns the workbook' do
    sheet = Export::Sheet.new(name: 'Veículos', relation: tenant.atua_vehicles)

    expect(described_class.call([sheet], client:)).to eq('xlsx bytes')
    expect(client).to have_received(:workbook).with([sheet.to_h])
  end

  it 'lets the error of the export service reach the caller' do
    allow(client).to receive(:workbook).and_raise(XlsxExport::RequestError, 'fora do ar')

    expect { described_class.call([Export::Sheet.new(name: 'Veículos', relation: tenant.atua_vehicles)], client:) }
      .to raise_error(XlsxExport::RequestError, 'fora do ar')
  end
end
