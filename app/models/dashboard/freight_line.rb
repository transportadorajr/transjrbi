module Dashboard
  FreightLine = Data.define(:transport_document, :loaded_km) do
    delegate :freight_cents, :net_cents, :issued_at, to: :transport_document

    class << self
      def gross_per_km(lines)
        per_km_of(lines, &:freight_cents)
      end

      def net_per_km(lines)
        per_km_of(lines, &:net_cents)
      end

      def per_km(cents, distance)
        Money.from_cents((cents.to_d / distance).round(0, BigDecimal::ROUND_HALF_UP)) if distance&.positive?
      end

      private

      def per_km_of(lines, &)
        measured = lines.select(&:measured?)

        per_km(measured.sum(&), measured.sum(BigDecimal('0'), &:loaded_km))
      end
    end

    def measured?
      loaded_km.to_d.positive?
    end

    def gross_per_km
      self.class.per_km(freight_cents, loaded_km)
    end

    def net_per_km
      self.class.per_km(net_cents, loaded_km)
    end
  end
end
