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

    it 'lists the error types' do
      expect(described_class.error_types.keys).to eq(%w[configuration authentication device_verification session download spreadsheet layout conversion unexpected])
    end

    it 'translates the error type' do
      expect(build(:atua_import, error_type: 'layout').error_type_name).to eq('Layout do relatório')
    end

    it 'rejects an unknown error type' do
      import = build(:atua_import, error_type: 'timeout')

      expect(import).not_to be_valid
      expect(import.errors.full_messages).to eq(['Tipo do erro não está incluído na lista'])
    end

    it 'maps the translated statuses to their keys' do
      expect(described_class.statuses).to eq(
        'Pendente' => 'pending', 'Em andamento' => 'running', 'Concluída' => 'succeeded', 'Falhou' => 'failed',
      )
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
                           updated_count: 3, removed_count: 2, error_message: 'Timeout', error_type: 'download',
                           warning_message: 'Alerta')
    end

    it 'restarts the import clearing the previous run' do
      import.start!

      expect(import.reload).to have_attributes(
        status_type: 'running', finished_at: nil, rows_read: 0, inserted_count: 0, updated_count: 0, removed_count: 0,
        error_message: nil, error_type: nil, warning_message: nil
      )
      expect(import.started_at).to be > 1.minute.ago
    end

    it 'finishes the import with its counts' do
      import.succeed!(rows_read: 5, inserted_count: 5)

      expect(import.reload).to have_attributes(status_type: 'succeeded', rows_read: 5, inserted_count: 5, error_message: nil, error_type: nil)
      expect(import.finished_at).to be > 1.minute.ago
    end

    it 'records the failure message as an unexpected error by default' do
      import.fail!('Planilha ilegível')

      expect(import.reload).to have_attributes(status_type: 'failed', error_message: 'Planilha ilegível', error_type: 'unexpected')
      expect(import.finished_at).to be > 1.minute.ago
    end

    it 'records the type of the failure' do
      import.fail!('Login recusado', error_type: :authentication)

      expect(import.reload).to have_attributes(status_type: 'failed', error_type: 'authentication')
    end

    it 'measures the duration of a finished run' do
      import = build(:atua_import, started_at: Time.zone.local(2026, 10, 14, 8), finished_at: Time.zone.local(2026, 10, 14, 8, 2, 5))

      expect(import.duration).to eq(125)
      expect(build(:atua_import, started_at: Time.current, finished_at: nil).duration).to be_nil
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

  describe '#action_required?' do
    it 'flags the failures that do not solve themselves' do
      expect(build(:atua_import, status_type: 'failed', error_type: 'authentication')).to be_action_required
      expect(build(:atua_import, status_type: 'failed', error_type: 'configuration')).to be_action_required
      expect(build(:atua_import, status_type: 'failed', error_type: 'layout')).to be_action_required
      expect(build(:atua_import, status_type: 'failed', error_type: 'device_verification')).to be_action_required
    end

    it 'does not flag other failures nor successful imports' do
      expect(build(:atua_import, status_type: 'failed', error_type: 'download')).not_to be_action_required
      expect(build(:atua_import, status_type: 'succeeded')).not_to be_action_required
    end
  end

  describe '#validate_reprocess' do
    context 'with a finished import that has a file' do
      let!(:import) { create(:atua_import, :with_file, status_type: 'failed') }

      it 'enqueues the reprocessing' do
        expect { import.validate_reprocess }.to have_enqueued_job(Atua::ReprocessImportJob).with(import.id)
        expect(import.errors).to be_empty
      end
    end

    context 'with an import still running' do
      let!(:import) { create(:atua_import, :with_file, status_type: 'running') }

      it 'refuses the reprocessing' do
        expect(import.validate_reprocess).to be_nil
        expect(import.errors.full_messages).to eq(['A importação ainda está em andamento.'])
        expect(Atua::ReprocessImportJob).not_to have_been_enqueued
      end
    end

    context 'with an import without file' do
      let!(:import) { create(:atua_import, status_type: 'failed') }

      it 'refuses the reprocessing' do
        expect(import.validate_reprocess).to be_nil
        expect(import.errors.full_messages).to eq(['A importação não tem arquivo para reprocessar.'])
        expect(Atua::ReprocessImportJob).not_to have_been_enqueued
      end
    end
  end

  describe 'filters' do
    let!(:tenant) { create(:tenant) }
    let!(:other_tenant) { create(:tenant) }
    let!(:september) { create(:atua_import, tenant:, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30)) }
    let!(:october) { create(:atua_import, tenant: other_tenant, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13)) }
    let!(:registry) do
      create(:atua_import, tenant:, report_type: 'customers', start_date: nil, end_date: nil, created_at: Time.zone.local(2026, 10, 5, 22, 30))
    end

    it 'filters by tenant' do
      expect(described_class.by_tenant(tenant.id)).to contain_exactly(september, registry)
    end

    it 'filters the imports whose period reaches the start date' do
      expect(described_class.by_period_start('2026-10-01')).to contain_exactly(october, registry)
    end

    it 'filters the imports whose period begins until the end date' do
      expect(described_class.by_period_end('2026-09-30')).to eq([september])
    end

    it 'uses the local creation day for the imports without period' do
      expect(described_class.by_period_start('2026-10-05').by_period_end('2026-10-05')).to contain_exactly(october, registry)
    end

    it 'returns nothing for an invalid date' do
      expect(described_class.by_period_start('ontem')).to be_empty
    end
  end

  describe '.latest_per_report and .requiring_action' do
    let!(:tenant) { create(:tenant) }
    let!(:solved) { create(:atua_import, tenant:, status_type: 'failed', error_type: 'authentication', created_at: 2.hours.ago) }
    let!(:latest) { create(:atua_import, tenant:, status_type: 'succeeded', created_at: 1.hour.ago) }
    let!(:layout) { create(:atua_import, tenant:, report_type: 'manifests', status_type: 'failed', error_type: 'layout') }
    let!(:download) { create(:atua_import, tenant:, report_type: 'expenses', status_type: 'failed', error_type: 'download') }

    it 'keeps only the last import of each tenant and report' do
      expect(described_class.latest_per_report).to contain_exactly(latest, layout, download)
    end

    it 'lists the latest failures that require action' do
      expect(described_class.latest_per_report.requiring_action).to eq([layout])
      expect(described_class.requiring_action).to contain_exactly(solved, layout)
    end
  end
end
