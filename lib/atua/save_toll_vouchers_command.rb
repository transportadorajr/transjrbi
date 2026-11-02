module Atua
  class SaveTollVouchersCommand < SaveReportCommand
    MODEL = TollVoucher
    MAPPER = MapTollVouchersCommand

    def call
      super.tap { DiscardExcludedPlatesCommand.call(tenant) }
    end
  end
end
