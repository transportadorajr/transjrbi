module WorkSchedules
  class TripDatesCommand
    class << self
      def call(tenant, driver_codes, dates)
        new(tenant, driver_codes, dates).call
      end
    end

    def initialize(tenant, driver_codes, dates)
      @tenant = tenant
      @driver_codes = Array(driver_codes).compact.uniq
      @dates = dates
    end

    def call
      return {} if driver_codes.empty?

      trips.each_with_object(Hash.new { |hash, code| hash[code] = Set.new }) do |(code, started_at, departure_on, issued_on, closed_at), result|
        start = started_at&.to_date || departure_on || issued_on
        next if start.nil?

        finish = closed_at&.to_date || (started_at ? Date.current : start)
        result[code].merge(dates.grep(start..finish))
      end
    end

    private

    attr_reader :tenant, :driver_codes, :dates

    def trips
      manifests = Atua::Manifest.arel_table
      documents = Atua::TransportDocument.arel_table

      Atua::ManifestDocument.active.where(tenant:).joins(:manifest, :transport_document)
        .merge(Atua::Manifest.trips)
        .merge(Atua::TransportDocument.active.not_canceled.where(driver_code: driver_codes))
        .where(manifests[:closed_at].eq(nil).or(manifests[:closed_at].gteq(dates.first.beginning_of_day)))
        .distinct
        .pluck(documents[:driver_code], manifests[:trip_started_at], manifests[:departure_on], manifests[:issued_on], manifests[:closed_at])
    end
  end
end
