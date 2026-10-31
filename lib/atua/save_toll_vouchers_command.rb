module Atua
  class SaveTollVouchersCommand < SaveReportCommand
    MODEL = TollVoucher
    MAPPER = MapTollVouchersCommand
  end
end
