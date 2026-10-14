require 'rails_helper'

RSpec.describe Atua::Import do
  describe 'enums' do
    it 'accepts every Atua report as report type' do
      expect(described_class.report_types.keys).to eq(%w[transport_documents manifests expenses customers vehicles])
    end

    it 'lists the import statuses' do
      expect(described_class.status_types.keys).to eq(%w[pending running succeeded failed])
    end

    it 'starts as pending' do
      expect(described_class.new.status_type).to eq('pending')
    end

    it 'translates the report type and the status' do
      import = build(:atua_import, report_type: 'expenses', status_type: 'failed')

      expect(import.report_type_name).to eq('Despesas')
      expect(import.status_type_name).to eq('Falhou')
    end

    it 'rejects an unknown report type' do
      import = build(:atua_import, report_type: 'invoices')

      expect(import).not_to be_valid
      expect(import.errors.full_messages).to eq(['Relatório não está incluído na lista'])
    end

    it 'rejects an unknown status' do
      import = build(:atua_import, status_type: 'lost')

      expect(import).not_to be_valid
      expect(import.errors.full_messages).to eq(['Situação não está incluído na lista'])
    end
  end

  describe 'validations' do
    it 'rejects an end date before the start date' do
      import = build(:atua_import, start_date: Date.new(2026, 10, 13), end_date: Date.new(2026, 10, 1))

      expect(import).not_to be_valid
      expect(import.errors.full_messages).to eq(['Data final não pode ser anterior à data inicial'])
    end

    it 'accepts an import without period' do
      expect(build(:atua_import, report_type: 'customers', start_date: nil, end_date: nil)).to be_valid
    end
  end

  describe '.with_expired_file' do
    context 'with imports of different ages' do
      let!(:expired) { create(:atua_import, :with_file, created_at: 61.days.ago) }
      let!(:recent) { create(:atua_import, :with_file, created_at: 59.days.ago) }
      let!(:expired_without_file) { create(:atua_import, created_at: 90.days.ago) }

      it 'returns only the imports whose file is older than 60 days' do
        expect(described_class.with_expired_file).to eq([expired])
        expect(described_class.count).to eq(3)
        expect(recent.file).to be_attached
        expect(expired_without_file.file).not_to be_attached
      end
    end
  end
end
