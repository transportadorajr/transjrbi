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

      (manifest_trips + ce_trips).each_with_object(Hash.new { |hash, code| hash[code] = Set.new }) do |(code, start, finish), result|
        result[code].merge(dates.grep(start..finish))
      end
    end

    private

    attr_reader :tenant, :driver_codes, :dates

    def manifest_trips
      trips.filter_map do |code, started_at, departure_on, issued_on, closed_at|
        start = started_at&.to_date || departure_on || issued_on
        next if start.nil?

        [code, start, closed_at&.to_date || (started_at ? Date.current : start)]
      end
    end

    def ce_trips
      tenant.atua_transport_documents.ce_trips.where(driver_code: driver_codes)
        .where(Atua::TransportDocument.arel_table[:issued_at].lteq(dates.last.end_of_day))
        .pluck(:driver_code, :issued_at, :arrival_on)
        .filter_map do |code, issued_at, arrival_on|
          start = issued_at.to_date
          finish = [arrival_on, start].compact.max
          [code, start, finish] if finish >= dates.first
        end
    end

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
