module Export
  module Value
    class << self
      def cast(type, raw)
        return if raw.nil?

        case type
        when :money then money(raw)
        when :date then raw.to_date.iso8601
        when :datetime then raw.in_time_zone.iso8601
        when :string then text(raw)
        when :integer then raw.is_a?(Numeric) ? raw.round : raw
        when :decimal, :percentage then raw.is_a?(Money) ? raw.to_d : raw
        else raw
        end
      end

      private

      def money(raw)
        raw.is_a?(Money) ? raw.cents : raw.to_i
      end

      def text(raw)
        case raw
        when Array then raw.join(', ')
        when Hash then raw.to_json
        else raw.to_s
        end
      end
    end
  end
end
