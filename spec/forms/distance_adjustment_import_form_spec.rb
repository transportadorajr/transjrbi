require 'rails_helper'

RSpec.describe DistanceAdjustmentImportForm do
  let!(:tenant) { create(:tenant) }

  describe '#save' do
    it 'imports an Excel spreadsheet' do
      file = Rack::Test::UploadedFile.new(xlsx_file([[74_120, 450]]), original_filename: 'km.xlsx')
      form = described_class.new(tenant:, file:)

      expect { form.save }.to change(DistanceAdjustment, :count).by(1)

      expect(form.result).to have_attributes(created: 1, pending: 1)
    end

    it 'requires the file' do
      form = described_class.new(tenant:)

      expect(form.save).to be_falsey
      expect(form.errors.full_messages).to eq(['Planilha não pode ficar em branco'])
    end

    it 'rejects a file that is not an Excel spreadsheet' do
      file = Rack::Test::UploadedFile.new(xlsx_file([[74_120, 450]]), original_filename: 'km.csv')
      form = described_class.new(tenant:, file:)

      expect { form.save }.not_to change(DistanceAdjustment, :count)
      expect(form.errors.full_messages).to eq(['Planilha deve ser uma planilha do Excel (.xlsx, .xls)'])
    end
  end
end
