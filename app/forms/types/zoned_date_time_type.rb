module Types
  class ZonedDateTimeType < ActiveModel::Type::DateTime
    private

    def cast_value(value)
      return super unless value.is_a?(::String)

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
