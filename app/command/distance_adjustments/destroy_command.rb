module DistanceAdjustments
  class DestroyCommand
    class << self
      def call(adjustment)
        new(adjustment).call
      end
    end

    def initialize(adjustment)
      @adjustment = adjustment
    end

    def call
      DistanceAdjustment.transaction do
        RevertCommand.call(adjustment.tenant, adjustment.transport_document_number)
        adjustment.destroy!
      end
    end

    private

    attr_reader :adjustment
  end
end
