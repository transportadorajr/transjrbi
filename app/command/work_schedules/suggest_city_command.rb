module WorkSchedules
  class SuggestCityCommand
    class << self
      def call(employee)
        new(employee).call
      end
    end

    def initialize(employee)
      @employee = employee
    end

    def call
      most_frequent_day_off_city || last_trip_destination
    end

    private

    attr_reader :employee

    def most_frequent_day_off_city
      days_off = employee.work_schedule_days.day_off.where.not(city_id: nil)
      city_id = days_off.group(:city_id).order(Arel.sql('COUNT(*) DESC, MAX(date) DESC')).pick(:city_id)

      employee.tenant.cities.find_by(id: city_id) if city_id
    end

    def last_trip_destination
      return if employee.driver_code.nil?

      manifest = employee.tenant.atua_manifests.trips.by_driver(employee.driver_code).where.not(closed_at: nil)
        .order(closed_at: :desc, id: :desc).preload(route_documents: :transport_document).first
      city, state = manifest&.final_destination
      return if city.blank?

      compacted_name = CustomerGroup.compact(city)
      employee.tenant.cities.activated.where(state:).find { |candidate| candidate.compacted_name == compacted_name }
    end
  end
end
