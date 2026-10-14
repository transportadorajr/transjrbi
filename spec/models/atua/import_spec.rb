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

  describe 'lifecycle' do
    let(:import) do
      create(:atua_import, status_type: 'failed', started_at: 1.day.ago, finished_at: 1.day.ago, rows_read: 10, inserted_count: 4,
                           updated_count: 3, removed_count: 2, error_message: 'Timeout', warning_message: 'Alerta')
    end

    it 'restarts the import clearing the previous run' do
      import.start!

      expect(import.reload).to have_attributes(
        status_type: 'running', finished_at: nil, rows_read: 0, inserted_count: 0, updated_count: 0, removed_count: 0,
        error_message: nil, warning_message: nil
      )
      expect(import.started_at).to be > 1.minute.ago
    end

    it 'finishes the import with its counts' do
      import.succeed!(rows_read: 5, inserted_count: 5)

      expect(import.reload).to have_attributes(status_type: 'succeeded', rows_read: 5, inserted_count: 5, error_message: nil)
      expect(import.finished_at).to be > 1.minute.ago
    end

    it 'records the failure message' do
      import.fail!('Planilha ilegível')

      expect(import.reload).to have_attributes(status_type: 'failed', error_message: 'Planilha ilegível')
      expect(import.finished_at).to be > 1.minute.ago
    end

    it 'has a period only when both dates are present' do
      expect(build(:atua_import)).to be_period
      expect(build(:atua_import, end_date: nil)).not_to be_period
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
