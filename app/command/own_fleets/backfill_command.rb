module OwnFleets
  class BackfillCommand
    DEFAULTS_PATH = Rails.root.join('config/own_fleet.yml')

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      own_fleet = OwnFleet.find_or_initialize_by(tenant:)
      return own_fleet if own_fleet.plates.any?

      own_fleet.update!(plates: defaults)
      own_fleet
    end

    private

    attr_reader :tenant

    def defaults
      YAML.load_file(DEFAULTS_PATH).map { |plate| Atua::TransportDocument.normalize_plate(plate) }.uniq.sort
    end
  end
end
