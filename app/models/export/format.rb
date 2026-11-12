module Export
  module Format
    class << self
      def for(type)
        I18n.t('xlsx_export.formats.money', unit: I18n.t('number.currency.format.unit')) if type == :money
      end
    end
  end
end
