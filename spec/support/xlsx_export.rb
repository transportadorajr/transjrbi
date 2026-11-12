require 'socket'

module XlsxExportService
  BINARY = ENV.fetch('XLSX_EXPORT_BINARY') { Rails.root.join('bin/xlsx_export').to_s }
  TOKEN = 'xlsx-export-test-token'.freeze
  BOOT_TIMEOUT = 10

  class << self
    def start
      return if @url

      raise "#{BINARY} not found. Run bin/setup to build the Excel export service." unless File.executable?(BINARY)

      port = free_port
      @url = "http://127.0.0.1:#{port}"
      pid = Process.spawn({ 'XLSX_EXPORT_BIND' => "127.0.0.1:#{port}", 'XLSX_EXPORT_TOKEN' => TOKEN, 'RUST_LOG' => 'warn' },
                          BINARY, 'serve', out: File::NULL)
      at_exit { stop(pid) }
      wait_until_up
    end

    def env
      { 'XLSX_EXPORT_URL' => @url, 'XLSX_EXPORT_TOKEN' => TOKEN }
    end

    private

    def free_port
      server = TCPServer.new('127.0.0.1', 0)
      server.addr[1]
    ensure
      server&.close
    end

    def wait_until_up
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + BOOT_TIMEOUT
      until up?
        raise "The Excel export service did not start at #{@url}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    def up?
      Net::HTTP.get_response(URI("#{@url}/up")).is_a?(Net::HTTPSuccess)
    rescue SystemCallError, IOError
      false
    end

    def stop(pid)
      Process.kill('TERM', pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end

module XlsxDownloads
  def downloaded_xlsx_workbook
    file = Tempfile.new(%w[download .xlsx], binmode: true)
    file.write(page.body)
    file.close

    Roo::Excelx.new(file.path)
  end

  def downloaded_xlsx_sheet_names
    downloaded_xlsx_workbook.sheets
  end

  def downloaded_xlsx_sheet(sheet = 0)
    downloaded_xlsx_workbook.sheet(sheet)
  end

  def downloaded_xlsx_rows(sheet = 0)
    sheet = downloaded_xlsx_sheet(sheet)
    return [] unless sheet.first_row

    (sheet.first_row..sheet.last_row).map { |index| sheet.row(index) }
  end

  def downloaded_xlsx_records(sheet = 0)
    headers, *rows = downloaded_xlsx_rows(sheet)

    rows.map { |row| headers.zip(row).to_h }
  end
end

RSpec.configure do |config|
  config.include XlsxDownloads

  config.around(:each, :xlsx_service) do |example|
    XlsxExportService.start
    ClimateControl.modify(XlsxExportService.env) { example.run }
  end
end
