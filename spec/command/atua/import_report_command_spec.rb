require 'rails_helper'

RSpec.describe Atua::ImportReportCommand do
  let(:tenant) { create(:tenant) }
  let(:period) { { start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13) } }

  def import_fixture(report_type, target: tenant, file: atua_fixture_path(report_type))
    dates = Atua::Report.find(report_type).period? ? period : {}

    described_class.call(target, report_type, file:, **dates).sole
  end

  def fixture_file_with(report_type, rows)
    spreadsheet = read_atua_fixture(report_type)

    write_atua_spreadsheet(totals: [], headers: spreadsheet.headers, rows: rows.map { |row| row.values_at(*spreadsheet.headers) })
  end

  describe '.call' do
    context 'with each report fixture' do
      it 'imports the customers' do
        import = import_fixture(:customers)

        expect(import).to have_attributes(
          tenant:, report_type: 'customers', status_type: 'succeeded', start_date: nil, end_date: nil,
          rows_read: 4833, inserted_count: 4833, updated_count: 0, removed_count: 0, error_message: nil, warning_message: nil
        )
        expect(import.started_at).to be_present
        expect(import.finished_at).to be_present
        expect(import.file.filename.to_s).to eq('customers.xls')
        expect(tenant.atua_customers.count).to eq(4833)
        expect(tenant.atua_customers.find_by!(code: 7752)).to have_attributes(import:, removed_from_atua_at: nil)
      end

      it 'imports the vehicles' do
        import = import_fixture(:vehicles)

        expect(import).to have_attributes(status_type: 'succeeded', rows_read: 1391, inserted_count: 1391, updated_count: 0)
        expect(tenant.atua_vehicles.count).to eq(1391)
      end

      it 'imports the manifests with their documents' do
        import = import_fixture(:manifests)

        expect(import).to have_attributes(
          status_type: 'succeeded', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13),
          rows_read: 390, inserted_count: 217, updated_count: 0, removed_count: 0
        )
        expect(tenant.atua_manifests.count).to eq(217)
        expect(tenant.atua_manifest_documents.count).to eq(390)
        expect(tenant.atua_manifests.find_by!(code: 41_239).documents.pluck(:transport_document_number))
          .to match_array(%w[74136 74134 74135 74137 74133])
      end

      it 'imports the transport documents with their manifest links' do
        import = import_fixture(:transport_documents)

        expect(import).to have_attributes(status_type: 'succeeded', rows_read: 420, inserted_count: 420, updated_count: 0)
        expect(tenant.atua_transport_documents.count).to eq(420)
        expect(tenant.atua_transport_document_manifests.count).to eq(377)
        expect(tenant.atua_transport_document_manifests.find_by!(transport_document_code: 80_842))
          .to have_attributes(manifest_number: '183', branch_name: 'EMPRESA 01', import:)
      end

      it 'imports the expenses grouping the rows of the same expense' do
        import = import_fixture(:expenses)

        expect(import).to have_attributes(status_type: 'succeeded', rows_read: 1218, inserted_count: 1217, updated_count: 0)
        expect(tenant.atua_expenses.count).to eq(1217)
      end
    end

    context 'when the same period is imported again' do
      before { import_fixture(:transport_documents) }

      it 'updates the records without duplicating them' do
        transport_document = tenant.atua_transport_documents.find_by!(code: 80_842)
        freight_cents = transport_document.freight_cents
        transport_document.update_columns(freight_cents: 1, created_at: 1.day.ago)

        import = import_fixture(:transport_documents)

        expect(import).to have_attributes(status_type: 'succeeded', inserted_count: 0, updated_count: 420, removed_count: 0)
        expect(tenant.atua_transport_documents.count).to eq(420)
        expect(tenant.atua_transport_document_manifests.count).to eq(377)
        expect(transport_document.reload).to have_attributes(import:, freight_cents:)
        expect(transport_document.created_at).to be < 1.hour.ago
      end

      it 'keeps the charge date stamped by the first import' do
        charged_at = tenant.atua_transport_documents.where.not(charged_at: nil).pick(:code, :charged_at)

        travel_to(1.day.from_now) { import_fixture(:transport_documents) }

        expect(tenant.atua_transport_documents.find_by!(code: charged_at.first).charged_at).to eq(charged_at.last)
      end

      it 'counts as inserted only the records that were not there yet' do
        tenant.atua_transport_documents.where(code: [80_842, 80_843]).delete_all

        import = import_fixture(:transport_documents)

        expect(import).to have_attributes(inserted_count: 2, updated_count: 418)
      end
    end

    context 'when the manifests are imported again' do
      before { import_fixture(:manifests) }

      it 'replaces the documents of each imported manifest' do
        manifest_documents = tenant.atua_manifest_documents.where(manifest_code: 41_239)
        manifest_documents.first.update_columns(transport_document_number: '1')

        import = import_fixture(:manifests)

        expect(import).to have_attributes(inserted_count: 0, updated_count: 217)
        expect(tenant.atua_manifest_documents.count).to eq(390)
        expect(manifest_documents.pluck(:transport_document_number)).to match_array(%w[74136 74134 74135 74137 74133])
        expect(manifest_documents.pluck(:atua_import_id).uniq).to eq([import.id])
      end
    end

    context 'with two tenants' do
      let(:other_tenant) { create(:tenant) }
      let!(:other_extra) { create(:atua_transport_document, tenant: other_tenant, code: 1) }
      let!(:extra) { create(:atua_transport_document, tenant:, code: 1) }

      it 'imports the same source keys into each tenant without colliding' do
        import_fixture(:transport_documents, target: other_tenant)
        import = import_fixture(:transport_documents)

        expect(import).to have_attributes(inserted_count: 420, updated_count: 0)
        expect(tenant.atua_transport_documents.count).to eq(421)
        expect(other_tenant.atua_transport_documents.count).to eq(421)
        expect(Atua::TransportDocument.where(code: 80_842).pluck(:tenant_id)).to contain_exactly(tenant.id, other_tenant.id)
      end

      it 'marks the removed records only of the imported tenant' do
        import = import_fixture(:transport_documents)

        expect(import.removed_count).to eq(1)
        expect(extra.reload.removed_from_atua_at).to be_present
        expect(other_extra.reload.removed_from_atua_at).to be_nil
      end
    end

    context 'with every report imported' do
      before do
        %i[customers vehicles manifests transport_documents].each { |report_type| import_fixture(report_type) }
      end

      let(:transport_document) { tenant.atua_transport_documents.find_by!(code: 80_842) }

      it 'links the transport document to its customers and vehicle' do
        expect(transport_document.sender).to eq(tenant.atua_customers.find_by!(code: 7752))
        expect(transport_document.vehicle).to eq(tenant.atua_vehicles.find_by!(code: 812))
      end

      it 'links the transport document and the manifest both ways' do
        manifest = tenant.atua_manifests.find_by!(number: '183', branch_name: 'EMPRESA 01')

        expect(transport_document.manifests).to eq([manifest])
        expect(transport_document.manifest_documents.map(&:manifest)).to eq([manifest])
        expect(manifest.transport_documents).to include(transport_document)
      end
    end

    context 'with records of the period that are no longer in the file' do
      let!(:missing) { create(:atua_transport_document, tenant:, code: 1, issued_at: Time.zone.local(2026, 10, 5, 8)) }
      let!(:missing_link) { create(:atua_transport_document_manifest, tenant:, transport_document_code: 1, manifest_number: '9') }
      let!(:outside_period) { create(:atua_transport_document, tenant:, code: 2, issued_at: Time.zone.local(2026, 11, 2, 8)) }
      let!(:returned) do
        create(:atua_transport_document, tenant:, code: 80_842, number: '397', removed_from_atua_at: 2.days.ago)
      end

      it 'marks only the missing records of the period as removed without deleting them' do
        import = import_fixture(:transport_documents)

        expect(import.removed_count).to eq(1)
        expect(missing.reload.removed_from_atua_at).to be_present
        expect(missing_link.reload.removed_from_atua_at).to be_present
        expect(outside_period.reload.removed_from_atua_at).to be_nil
        expect(tenant.atua_transport_documents.count).to eq(422)
      end

      it 'clears the removal of the records that came back' do
        import_fixture(:transport_documents)

        expect(returned.reload.removed_from_atua_at).to be_nil
      end
    end

    context 'with registrations that are no longer in the file' do
      let!(:missing) { create(:atua_vehicle, tenant:, code: 1) }

      it 'marks them as removed considering the whole registry' do
        import = import_fixture(:vehicles)

        expect(import.removed_count).to eq(1)
        expect(missing.reload.removed_from_atua_at).to be_present
        expect(tenant.atua_vehicles.active.count).to eq(1391)
      end
    end

    context 'when the file is empty' do
      let!(:manifests) { create_list(:atua_manifest, 2, tenant:) }
      let(:path) { fixture_file_with(:manifests, []) }

      after { FileUtils.rm_f(path) }

      it 'does not mark any removal and records an alert' do
        import = import_fixture(:manifests, file: path)

        expect(import).to have_attributes(status_type: 'succeeded', rows_read: 0, removed_count: 0)
        expect(import.warning_message).to eq(
          'O arquivo trouxe 0 registro(s), menos da metade dos 2 que o banco tem para o mesmo período: ' \
          'nenhum registro foi marcado como removido da Atua.',
        )
        expect(tenant.atua_manifests.active.count).to eq(2)
      end
    end

    context 'when the file has less than half of the records of the period' do
      let!(:manifests) { create_list(:atua_manifest, 3, tenant:) }
      let(:path) { fixture_file_with(:manifests, read_atua_fixture(:manifests).rows.first(1)) }

      after { FileUtils.rm_f(path) }

      it 'imports the records but does not mark any removal' do
        import = import_fixture(:manifests, file: path)

        expect(import).to have_attributes(status_type: 'succeeded', inserted_count: 1, removed_count: 0)
        expect(import.warning_message).to include('1 registro(s), menos da metade dos 3')
        expect(tenant.atua_manifests.active.count).to eq(4)
      end
    end

    context 'when the file has half of the records of the period' do
      let!(:manifests) { create_list(:atua_manifest, 2, tenant:) }
      let(:path) { fixture_file_with(:manifests, read_atua_fixture(:manifests).rows.first(1)) }

      after { FileUtils.rm_f(path) }

      it 'marks the missing records as removed' do
        import = import_fixture(:manifests, file: path)

        expect(import).to have_attributes(removed_count: 2, warning_message: nil)
      end
    end

    context 'when a period report file is imported without a period' do
      let!(:manifest) { create(:atua_manifest, tenant:) }

      it 'imports the records without checking removals' do
        import = described_class.call(tenant, :manifests, file: atua_fixture_path(:manifests)).sole

        expect(import).to have_attributes(status_type: 'succeeded', inserted_count: 217, removed_count: 0)
        expect(import.warning_message).to eq(
          'O arquivo foi importado sem período, por isso os registros que sumiram da Atua não foram verificados.',
        )
        expect(manifest.reload.removed_from_atua_at).to be_nil
      end
    end

    context 'when the report is downloaded from Atua' do
      let(:client) { instance_double(Atua::Client) }

      def download(start_date, end_date)
        Atua::Download.new(
          report_type: :manifests, start_date:, end_date:, content: atua_fixture_path(:manifests).binread,
          content_type: 'application/vnd.ms-excel', filename: '9430_rel_manifesto_detalhado.xls'
        )
      end

      before do
        allow(client).to receive(:download) { |_type, start_date:, end_date:| [download(start_date, end_date)] }
      end

      it 'attaches the downloaded file and imports it' do
        import = described_class.call(tenant, :manifests, **period, client:).sole

        expect(client).to have_received(:download).with(:manifests, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))
        expect(import).to have_attributes(status_type: 'succeeded', inserted_count: 217)
        expect(import.file.filename.to_s).to eq('9430_rel_manifesto_detalhado.xls')
      end

      it 'creates one import for each month of a long period' do
        imports = described_class.call(tenant, :manifests, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 10, 13), client:)

        expect(imports.map { |import| [import.start_date, import.end_date] }).to eq(
          [[Date.new(2026, 9, 1), Date.new(2026, 9, 30)], [Date.new(2026, 10, 1), Date.new(2026, 10, 13)]],
        )
        expect(imports.map(&:status_type)).to eq(%w[succeeded succeeded])
        expect(client).to have_received(:download).twice
      end
    end

    context 'when the download fails' do
      let(:client) { instance_double(Atua::Client) }

      before { allow(client).to receive(:download).and_raise(Atua::DownloadError, 'O relatório manifests não veio em Excel (.xls).') }

      it 'records the failure in the import' do
        import = described_class.call(tenant, :manifests, **period, client:).sole

        expect(import).to have_attributes(status_type: 'failed', error_message: 'O relatório manifests não veio em Excel (.xls).')
        expect(import.finished_at).to be_present
        expect(import.file).not_to be_attached
        expect(tenant.atua_manifests.count).to eq(0)
      end
    end

    context 'when the configuration is incomplete' do
      before { allow(Atua::Configuration).to receive(:for).with(tenant).and_raise(Atua::ConfigurationError, 'Configuração da Atua incompleta.') }

      it 'records the failure in the import' do
        import = described_class.call(tenant, :customers).sole

        expect(import).to have_attributes(status_type: 'failed', error_message: 'Configuração da Atua incompleta.')
      end
    end

    context 'when the file does not have the layout of the report' do
      it 'records the failure and saves nothing' do
        import = import_fixture(:manifests, file: atua_fixture_path(:vehicles))

        expect(import.status_type).to eq('failed')
        expect(import.error_message).to start_with('O relatório rel_manifesto_detalhado veio sem as colunas obrigatórias')
        expect(import.file).to be_attached
        expect(tenant.atua_manifests.count).to eq(0)
      end
    end
  end
end
