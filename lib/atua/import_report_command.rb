module Atua
  class ImportReportCommand
    CONTENT_TYPE = 'application/vnd.ms-excel'.freeze

    class << self
      def call(tenant, report_type, start_date: nil, end_date: nil, file: nil, client: nil, raise_errors: false)
        new(tenant, report_type, start_date:, end_date:, file:, client:, raise_errors:).call
      end
    end

    def initialize(tenant, report_type, start_date: nil, end_date: nil, file: nil, client: nil, raise_errors: false)
      @tenant = tenant
      @report = Report.find(report_type)
      @start_date = start_date&.to_date
      @end_date = end_date&.to_date
      @file = file
      @client = client
      @raise_errors = raise_errors
    end

    def call
      periods.map { |period_start, period_end| import_period(period_start, period_end) }
    end

    private

    attr_reader :tenant, :report, :start_date, :end_date, :file, :raise_errors

    def periods
      file ? [[start_date, end_date]] : report.periods(start_date, end_date)
    end

    def import_period(period_start, period_end)
      import = tenant.atua_imports.create!(
        report_type: report.type, start_date: period_start, end_date: period_end, status_type: :running, started_at: Time.current,
        source_type: file ? :upload : nil
      )
      import.file.attach(file ? uploaded_file : downloaded_file(import, period_start, period_end))

      ProcessImportCommand.call(import, raise_errors:)
    rescue StandardError => e
      raise unless import&.persisted?

      FailImportCommand.call(import, e) unless import.failed?
      raise if raise_errors

      import
    end

    def uploaded_file
      path = file.is_a?(File) ? file.path : file
      return file unless path.is_a?(Pathname) || (path.is_a?(String) && File.file?(path))

      { io: StringIO.new(File.binread(path)), filename: File.basename(path), content_type: CONTENT_TYPE }
    end

    def downloaded_file(import, period_start, period_end)
      import.update!(source_type: client.source_type)
      download = Current.set(atua_import: import) { client.download(report.type, start_date: period_start, end_date: period_end).sole }

      { io: StringIO.new(download.content), filename: download.filename, content_type: CONTENT_TYPE }
    end

    def client
      @client ||= Client.new(Configuration.for(tenant))
    end
  end
end
