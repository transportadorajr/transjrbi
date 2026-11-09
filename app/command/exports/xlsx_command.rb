module Exports
  class XlsxCommand
    class << self
      def call(sheets, client: XlsxExport::Client.new)
        new(sheets, client).call
      end
    end

    def initialize(sheets, client)
      @sheets = sheets
      @client = client
    end

    def call
      client.workbook(sheets.map(&:to_h))
    end

    private

    attr_reader :sheets, :client
  end
end
