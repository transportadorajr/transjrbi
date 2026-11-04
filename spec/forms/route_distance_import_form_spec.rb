require 'rails_helper'

RSpec.describe RouteDistanceImportForm do
  let!(:tenant) { create(:tenant) }
  let!(:customer) { create(:atua_customer, tenant:, code: 7001, document_digits: '17469701006612') }
  let(:rows) { [['17469701006612', 'IPATINGA', 'MG', 'CAXIAS DO SUL', 'RS', 1450]] }

  describe '#save' do
    it 'imports an Excel spreadsheet' do
      file = Rack::Test::UploadedFile.new(xlsx_file(rows), original_filename: 'km.xlsx')
      form = described_class.new(tenant:, file:)

      expect { form.save }.to change(RouteDistance, :count).by(1)

      expect(form.result).to have_attributes(created: 1, updated: 0, documents: 0)
    end

    it 'requires the file' do
      form = described_class.new(tenant:)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Planilha não pode ficar em branco'])
    end

    it 'rejects a file that is not an Excel spreadsheet' do
      file = Rack::Test::UploadedFile.new(xlsx_file(rows), original_filename: 'km.csv')
      form = described_class.new(tenant:, file:)

      expect { form.save }.not_to change(RouteDistance, :count)
      expect(form.errors.full_messages).to eq(['Planilha deve ser uma planilha do Excel (.xlsx, .xls)'])
    end
  end
end
