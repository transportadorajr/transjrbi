module RouteDistances
  class DestroyCommand
    class << self
      def call(route_distance)
        new(route_distance).call
      end
    end

    def initialize(route_distance)
      @route_distance = route_distance
    end

    def call
      RouteDistance.transaction do
        route_distance.destroy!
        ApplyCommand.call(route_distance.tenant)
      end
    end

    private

    attr_reader :route_distance
  end
end
